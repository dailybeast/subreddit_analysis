require 'rubygems'
require 'bundler/setup'
require 'redd'
require 'yaml'
require 'json'
require 'sqlite3'
require 'csv'
require_relative 'models/base'
require_relative 'models/subreddit'
require_relative 'models/subreddit_submission'
require_relative 'models/subreddit_comment'
require_relative 'models/user'
require_relative 'models/user_comment'
require_relative 'models/user_submission'

class SubredditAnalysis
  attr_accessor :props, :client, :access
  attr_reader :db

  COMMENTER_TYPE = 'comments'
  SUBMISSION_TYPE = 'submissions'
  USER_SUBMISSION_TYPE = 'user_submissions'
  USER_COMMENT_TYPE = 'user_comments'

  def initialize(config_file, props = {})
    @environment = ENV['environment'] || 'production'
    log("Running in #{@environment} mode.")
    @props = YAML.load_file(config_file).merge(props)
    @db = init_db
  end

  def close
    @db.close if @db
  end

  def authorize
    log("authorizing")
    @client = Redd.it(:script, props['client_id'], props['client_secret'], props['username'], props['password'], user_agent: props['user_agent'])
    @access = @client.authorize!
  end

  def crawl_subreddit_submissions_and_comments(subreddit, depth = @props['submission_depth'])
    return crawl_subreddit(depth, subreddit)
  end

  def crawl_subreddit_comments(subreddit, submission, depth = @props['comment_depth'])
    return crawl_subreddit(depth, subreddit, submission)
  end

  def users_other_submissions(subreddit)
    crawl_user(USER_SUBMISSION_TYPE, subreddit)
  end

  def users_other_comments(subreddit)
    crawl_user(USER_COMMENT_TYPE, subreddit)
  end

  # def analyze(subreddit)
  #   result = @db.execute <<-SQL
  #     select s.subreddit_name, sum(s.count) as total from
  #       (
  #         select count(*) as count, subreddit_name
  #             from user_submissions
  #             where user_name in
  #               (select distinct(name) from subreddit_comments where subreddit_name='#{subreddit.name}'
  #               union
  #               select distinct(name) from subreddit_submitters where subreddit_name='#{subreddit.name}' collate nocase order by name asc)
  #             and subreddit_name <> '#{subreddit.name}' collate NOCASE
  #         union
  #           select count(*) as count, subreddit_name
  #               from user_comments
  #               where user_name in
  #                 (select distinct(name) from subreddit_comments where subreddit_name='#{subreddit.name}'
  #                 union
  #                 select distinct(name) from subreddit_submitters where subreddit_name='#{subreddit.name}' collate nocase order by name asc)
  #               and subreddit_name <> '#{subreddit.name}' collate NOCASE
  #               group by subreddit_name
  #               order by subreddit_name
  #         ) as s
  #     group by s.subreddit_name
  #     order by total desc
  #     SQL
  #     filename = "reports/#{subreddit.name}_#{DateTime.now.strftime('%Y_%m_%d')}.csv"
  #     log("writing results to #{filename}")
  #     CSV.open(filename, "wb") do |csv|
  #       csv << ["count", "subreddit"]
  #       for row in result
  #         csv << row
  #       end
  #     end
  # end

  def self.run(subreddit)
    begin
      tries = 0
      bot = SubredditAnalysis.new('./config/config.yml')
      bot.authorize
      subreddit = Subreddit.find_or_create(subreddit, bot.client)
      bot.crawl_subreddit(subreddit)
      bot.crawl_subreddit_users(subreddit)
      bot.analyze(subreddit)
      puts "done."
    rescue Exception => e
      bot.close if bot
      puts e
      puts e.backtrace
      if (++tries <= 2) then
        sleep(3600)
        puts "Try again...(attempt #{tries} of 3)"
        SubredditAnalysis.run(subreddit)
      end
    ensure
      bot.close if bot
    end
  end

  private

  def log(message)
    unless(ENV['environment'] == 'test') then
      puts message
      puts message.backtrace if message.respond_to?(:backtrace)
    end
  end

  def crawl_user(type, subreddit)
    users = comments_and_submitters(subreddit)
    puts "USERS #{users}"
    depth = type === USER_COMMENT_TYPE ? @props['comment_depth'] : @props['submission_depth']
    for name in users do
      begin
        log("find #{type} for #{name}")
        user = User.find_or_create(name, client)
        count = type === USER_COMMENT_TYPE ? user.comments_ended_at : user.submissions_ended_at
        count = type === USER_COMMENT_TYPE ? user.comments.length : user.submissions.length
        #:count (Integer) — default: 0 — The number of items already seen in the listing.
        #:limit (1..100) — default: 25 — The maximum number of things to return.
        limit = depth - count  > 100 ? 100 : depth - count
        if (limit > 0) then
          (count..depth-1).each_slice(limit) do |a|
            log("retrieve #{limit} comments for #{name} starting at #{a.first}")
            type === USER_COMMENT_TYPE ? user.get_comments(limit, a.first) : user.get_submissions(limit, a.first)
          end
          user.save
        else
          log("Already at #{count} #{type}. Skip.")
        end
      rescue Exception => e
        log(e)
      end
    end
  end


  def crawl_subreddit(depth, subreddit, submission = nil)
    data = read(display_name, type, { 'name' => display_name, 'ended_at' => 0, type => [], "id" => id })
    #:count (Integer) — default: 0 — The number of items already seen in the listing.
    #:limit (1..100) — default: 25 — The maximum number of things to return.
    count =   data['ended_at']
    limit = depth - count  > 100 ? 100 : depth - count
    if (limit > 0) then
      (count..depth-1).each_slice(limit) do |a|
        log("retrieve #{limit} #{type} for #{display_name} #{submission.nil? ? '' : "new submission: " + submission.id} starting at #{a.first}")
        if (submission.nil?)
          data = get_submitters(subreddit, data, limit, a.first)
        else
          data = get_comments(subreddit, data, limit, a.first)
        end
        log("saving #{data[type].length}...")
        save(display_name, type, data)
      end
    else
      log("Already at #{data['ended_at']} #{type}. Skip.")
    end
    return data
  end


  def comments_and_submitters(subreddit)
    c =  @db.execute "select name from subreddit_comments where subreddit_name='#{subreddit.name}'"
    puts "COMMENTERS #{c}"
    s = @db.execute "select name from subreddit_submitters where subreddit_name='#{subreddit.name}'"
    puts "SUBMITTERS #{s}"
    puts "FLATTEN UNQ SORT #{(c.flatten + s.flatten).sort.uniq}"
    return (c.flatten + s.flatten).sort.uniq
  end

  def get_comments(subreddit, data, limit, count)
    comment_list = subreddit.reddit_object.get_comments(limit: limit, count: count, after: data['after'])
    return to_author_list(comment_list, COMMENTER_TYPE, data, limit, count)
  end

  def get_submitters(subreddit, data, limit, count)
    submission_list = subreddit.reddit_object.get_new(limit: limit, count: count, after: data['after'])
    submission_list.each { |s| crawl_subreddit_comments(subreddit, s) }
    return to_author_list(submission_list, SUBMITTER_TYPE, data, limit, count)
  end

  def to_author_list(list, type, data, limit, count)
    authors = list.map { |s| s.author }
    data[type] = (data[type] + authors).uniq
    data['ended_at'] = limit + count
    data['after'] = list.last.id
    return data
  end

  def init_db
    db = SQLite3::Database.new "#{@props['data_folder']}/subreddit_analysis_#{@environment}.db"
    Base.connections(db)
    Subreddit.init_table
    SubredditSubmission.init_table
    SubredditComment.init_table
    User.init_table
    UserComment.init_table
    UserSubmission.init_table
    return db
  end
end
