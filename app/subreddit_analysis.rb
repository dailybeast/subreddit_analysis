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
    client = Redd.it(:script,
                      props['client_id'],
                      props['client_secret'],
                      props['username'],
                      props['password'],
                      user_agent: props['user_agent'])
    client.authorize!
    Base.reddit_client(client)
  end

  def crawl_subreddit(subreddit)
    crawl_subreddit_submissions(subreddit)
    crawl_subreddit_comments(subreddit)
  end

  def crawl_subreddit_submissions(subreddit, total_limit = @props['submission_limit'])
    #:count (Integer) — default: 0 — The number of items already seen in the listing.
    #:limit (1..100) — default: 25 — The maximum number of things to return.
    count = subreddit.ended_at
    limit = total_limit - count  > 100 ? 100 : total_limit - count
    if (limit > 0)
      (count..total_limit-1).each_slice(limit) do |a|
        log("retrieve #{limit} Submissions for Subreddit #{subreddit.name} starting at #{a.first}")
        subreddit.get_submissions(limit, a.first)
        log("saving #{subreddit.submissions.length}...")
        subreddit.save
      end
    else
      log("Already at Subreddit #{subreddit.name} #{subreddit.ended_at}. Skip.")
    end
  end

  def crawl_subreddit_comments(subreddit, total_limit = @props['comment_limit'])
    #:count (Integer) — default: 0 — The number of items already seen in the listing.
    #:limit (1..100) — default: 25 — The maximum number of things to return.
    for submission in subreddit.submissions do
      count = submission.ended_at
      limit = total_limit - count  > 100 ? 100 : total_limit - count
      if (limit > 0)
        (count..total_limit-1).each_slice(limit) do |a|
          log("retrieve #{limit} for Comments for Submission #{submission.name} for Subreddit #{submission.subreddit.name} starting at #{a.first}")
          submission.get_comments(limit, a.first)
          log("saving #{submission.comments.length}...")
          submission.save
        end
      else
        log("Already at Submission #{submission.name} #{submission.ended_at}. Skip.")
      end
    end
  end

  def crawl_users(subreddit)
    users = subreddit.unique_submitters_and_commenters
    for name in users do
      user = User.find_or_create(name)
      crawl_user(user, UserSubmission)
      crawl_user(user, UserComment)
    end
  end

  def crawl_user(user, klass, total_limit = @props['user_activity_limit'])
    begin
      log("find #{klass.name}s for #{user.name}")
      counters = user.get_counters(klass)
      count = counters[:ended_at]
      #:count (Integer) — default: 0 — The number of items already seen in the listing.
      #:limit (1..100) — default: 25 — The maximum number of things to return.
      limit = total_limit - count  > 100 ? 100 : total_limit - count
      if (limit > 0) then
        (count..total_limit-1).each_slice(limit) do |a|
          log("retrieve #{limit} #{klass.name} for user #{user.name} starting at #{a.first}")
          if (klass == UserSubmission)
            user.get_submissions(limit, a.first)
          else
            user.get_comments(limit, a.first)
          end
          user.save
        end
      else
        log("Already at #{count} for #{klass.name}s for user #{user.name}. Skip.")
      end
    rescue Exception => e
      log(e)
    end
  end


  def analyze(subreddit)
    result = @db.execute <<-SQL
      select subreddit_name, count(*) as count from
        (select user_name, subreddit_name from
          (select user_name, subreddit_name from
            (select user_name, subreddit_name from user_submissions
              union
             select user_name, subreddit_name from user_comments) as all_user_activity)
        where user_name in
          (select distinct(user_name) from
            (select user_name from subreddit_comments where subreddit_name='#{subreddit.name}' collate nocase
              union
              select user_name from subreddit_submissions where subreddit_name='#{subreddit.name}' collate nocase
            ) as subreddit_users))
        group by subreddit_name
        order by count desc
    SQL
    filename = "reports/#{subreddit.name}_#{DateTime.now.strftime('%Y_%m_%d')}.csv"
    log("writing results to #{filename}")
    CSV.open(filename, "wb") do |csv|
      csv << ["count", "subreddit"]
      for row in result
        csv << row
      end
    end
  end

  def self.run(name, retries=0)
    begin
      bot = SubredditAnalysis.new('./config/config.yml')
      bot.authorize
      subreddit = Subreddit.find_or_create(name)
      bot.crawl_subreddit(subreddit)
      bot.crawl_users(subreddit)
      bot.analyze(subreddit)
      puts "done."
    rescue Exception => e
      bot.close if bot
      log(e)
      if ((retries += 1) <= 9) then
        log("Going to sleep after error. Try again...(attempt #{retries} of 10)")
        sleep(1800)
        log("Waking up! Try again...(attempt #{retries} of 10)")
        SubredditAnalysis.run(name, retries)
      else
        log("Failed after #{retries} retries.")
      end
    ensure
      bot.close if bot
    end
  end

  private

  def self.log(message)
    unless(ENV['environment'] == 'test') then
      File.open("#{DateTime.now.strftime('%Y_%m_%d')}.log", 'a') do |file|
        puts message
        file.puts(message)
        if message.respond_to?(:backtrace)
          puts message.backtrace
          file.puts(message.backtrace)
        end
      end

    end
  end

  def log(message)
    SubredditAnalysis.log(message)
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
