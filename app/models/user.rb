require 'json'
require_relative 'base_reddit'
require_relative 'user_comment'
require_relative 'user_submission'

class User < BaseReddit
  attr_accessor :name, :metadata, :submissions_ended_at, :submissions_after
  attr_accessor :comments_ended_at, :comments_after, :reddit_object
  attr_accessor :comments, :submissions

  def initialize(props = {})
    @submissions = []
    @comments = []
    @submissions_ended_at = 0
    @comments_ended_at = 0
    super(props)
  end

  def reddit_object
    if(@reddit_object.nil?)
      @reddit_object = @@reddit_client.user_from_name(@name)
    end
    @reddit_object
  end

  def save
    @@db.execute "insert or ignore into users (name) values ('#{name}');"
    @@db.execute <<-SQL
      update users
        set metadata='#{metadata}',
        submissions_ended_at=#{submissions_ended_at},
        submissions_after='#{submissions_after}',
        comments_ended_at='#{comments_ended_at}',
        comments_after='#{comments_after}'
        where name='#{name}' collate nocase;
      SQL
      for submission in submissions do
        submission.save
      end
      for comment in comments do
        comment.save
      end
    return true
  end

  def get_submissions(limit, count)
    result = get_from_reddit(UserSubmission, @submissions, @submissions_ended_at, @submissions_after, limit, count)
    @submissions = result[:result_list]
    @submissions_ended_at = result[:ended_at]
    @submissions_after = result[:after]
    return true
  end

  def get_comments(limit, count)
    result = get_from_reddit(UserComment, @comments, @comments_ended_at, @comments_after, limit, count)
    @comments = result[:result_list]
    @comments_ended_at = result[:ended_at]
    @comments_after = result[:after]
    return true
  end

  def self.find_or_create(name)
    self.find(name) || self.create(name)
  end

  def self.find(name)
    row = self.find_one <<-SQL
      select name, metadata,
      submissions_ended_at, submissions_after,
      comments_ended_at, comments_after
      from users
      where name = '#{name}' COLLATE NOCASE;
    SQL
    unless (row.nil?)
      user = User.new
      user.name = row[0]
      user.metadata = row[1]
      user.submissions_ended_at = row[2]
      user.submissions_after = row[3]
      user.comments_ended_at = row[4]
      user.comments_after = row[5]
      user.submissions = UserSubmission.find_for(user)
      user.comments = UserComment.find_for(user)
      return user
    else
      return nil
    end
  end

  def self.create(name)
    user = User.new
    user.reddit_object = @@reddit_client.user_from_name(name)
    user.name = user.reddit_object.name
    user.metadata = JSON.pretty_generate(JSON.parse(user.reddit_object.to_json)).gsub("'", "''")
    user.save
    return user
  end

  def self.init_table
    @@db.execute <<-SQL
    create table if not exists users (
      name varchar(255) PRIMARY KEY,
      metadata text,
      submissions_ended_at integer,
      submissions_after varchar(255),
      comments_ended_at integer,
      comments_after varchar(255)
    );
    SQL
  end

  # private
  #
  #
  #   def get_from_reddit(klass, list_attr, ended_at, after, limit, count)
  #     args = { limit: limit, count: count }
  #     if(after)
  #       args[:after] = after
  #     end
  #     if klass == UserComment
  #       list = reddit_object.get_comments(args)
  #     else
  #       list = reddit_object.get_submissions(args)
  #     end
  #     if (list.length > 0)
  #       list_attr = (list_attr + list.map {|r| klass.new({ user: self, subreddit_name: r.subreddit}) }).uniq { |c| self.name + c.subreddit_name }
  #       ended_at += limit
  #       after = list.last.fullname
  #     end
  #     return {ended_at: ended_at, after: after}
  #   end


end
