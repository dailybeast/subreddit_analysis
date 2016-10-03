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
    @@db.execute "insert or ignore into subreddits (name) values ('#{name}');"
    @@db.execute "update subreddits set metadata='#{metadata}', ended_at=#{ended_at}, after='#{after}' where name='#{name}' collate nocase;"
    for submission in submissions do
      submission.save
    end
    return true
  end

  def get_submissions(limit, count)
    result = get_from_reddit(SubredditSubmission, @submissions, ended_at, after, limit, count)
    @submissions = result[:result_list]
    @ended_at = result[:ended_at]
    @after = result[:after]
    return true
  end

  def self.find_or_create(name)
    return self.find(name) || self.create(name)
  end

  def self.find(name)
    row = self.find_one("select name, ended_at, after from subreddits where name = '#{name}' COLLATE NOCASE;")
    unless row.nil?
      subreddit = Subreddit.new
      subreddit.name = row[0]
      subreddit.ended_at = row[1]
      subreddit.after = row[2]
      return subreddit
    else
      return nil
    end
  end

  def self.create(name)
    subreddit = Subreddit.new(name: name)
    subreddit.reddit_object
    subreddit.metadata = JSON.pretty_generate(JSON.parse(subreddit.reddit_object.to_json)).gsub("'", "''")
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
