require 'json'
require_relative 'base_reddit'

class Subreddit < BaseReddit
  attr_accessor :name, :metadata, :ended_at, :after, :reddit_object, :submissions

  def initialize(props = {})
    @ended_at = 0
    @submissions = []
    super(props)
  end

  def reddit_object
    if(@reddit_object.nil?)
      @reddit_object = @@reddit_client.subreddit_from_name(@name)
    end
    @reddit_object
  end

  def save
    @@db.execute "insert or ignore into subreddits (name) values (#{quote(name)});"
    @@db.execute "update subreddits set metadata=#{quote(metadata)}, ended_at=#{quote(ended_at)}, after=#{quote(after)} where name=#{quote(name)} collate nocase;"
    for submission in submissions do
      submission.save
    end
    return self
  end

  def get_submissions(limit, count)
    result = get_from_reddit(SubredditSubmission, @submissions, ended_at, after, limit, count)
    @submissions = result[:result_list]
    @ended_at = result[:ended_at]
    @after = result[:after]
    return @submissions
  end

  def unique_submitters_and_commenters
    (SubredditSubmission.unique_submitters_for(self) + SubredditComment.unique_commenters_for(self)).uniq
  end

  def self.find_or_create(name)
    return self.find(name) || self.create(name)
  end

  def self.find(name)
    row = self.find_one("select name, ended_at, after from subreddits where name = #{quote(name)} COLLATE NOCASE;")
    unless row.nil?
      subreddit = Subreddit.new
      subreddit.name = row[0]
      subreddit.ended_at = row[1]
      subreddit.after = row[2]
      subreddit.submissions = SubredditSubmission.find_for(subreddit)
      return subreddit
    else
      return nil
    end
  end

  def self.create(name)
    subreddit = Subreddit.new(name: name)
    subreddit.metadata = JSON.pretty_generate(JSON.parse(subreddit.reddit_object.to_json))
    subreddit.save
    return subreddit
  end

  def self.init_table
    @@db.execute <<-SQL
      create table if not exists subreddits (
        name varchar(255) PRIMARY KEY,
        metadata text,
        ended_at integer,
        after varchar(255)
      );
    SQL
  end


end
