require_relative 'base_reddit'

class SubredditSubmission < BaseReddit
  attr_accessor :subreddit, :name, :id, :user_name, :ended_at, :after, :comments

  def initialize(props = {})
    @ended_at = 0
    @comments = []
    super(props)
  end

  def get_comments(limit, count)
    result = get_from_reddit(SubredditComment, @comments, ended_at, after, limit, count)
    @comments = result[:result_list]
    @ended_at = result[:ended_at]
    @after = result[:after]
    return true
  end

  def reddit_object
    @subreddit.reddit_object
  end

  def save
    @@db.execute <<-SQL
      insert or replace into subreddit_submissions
        (subreddit_name, name, id, user_name, ended_at, after)
        values ('#{subreddit.name}', '#{name}', '#{id}', "#{user_name}", #{ended_at}, '#{after}');
    SQL
    for comment in comments
      comment.save
    end
    return self
  end

  def self.init_table
    @@db.execute <<-SQL
      create table if not exists subreddit_submissions (
        subreddit_name varchar(255) references subreddits(name) ON UPDATE CASCADE,
        name varchar(255),
        id varchar(255) PRIMARY KEY,
        user_name varchar(255),
        ended_at integer,
        after varchar(255)
      );
    SQL
  end

  protected
  #internal use - see base_reddit.get_from_reddit

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_new(args)
  end

  def self.constructor_args_for_reddit_object(parent, raw_object)
    { subreddit: parent, name: raw_object.fullname, user_name: raw_object.author, id: raw_object.id }
  end

  def self.unique_parent_child(parent, child)
    parent.name + child.name
  end


end
