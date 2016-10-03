require_relative 'base'

class SubredditSubmission < Base
  attr_accessor :subreddit, :name, :id, :ended_at, :after, :comments

  def initialize(props = {})
    @ended_at = 0
    @comments = []
    super(props)
  end

  #TODO get_comments

  def save
    @@db.execute <<-SQL
      insert or replace into subreddit_submissions
        (subreddit_name, name, id, ended_at, after)
        values ('#{subreddit.name}', '#{id}', '#{name}', #{ended_at}, '#{after}');
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
    { subreddit: parent, name: raw_object.author, id: raw_object.id }
  end

  def self.unique_parent_child(parent, child)
    parent.name + child.id
  end


end
