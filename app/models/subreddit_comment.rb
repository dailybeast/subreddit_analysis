require_relative 'base'

class SubredditComment < Base
  attr_accessor :subreddit, :submission, :name, :id, :user_name
  def initialize(props = {})
    super
    unless (submission.comments.include?(self))
      submission.comments.push(self)
    end
  end

  def save
    @@db.execute <<-SQL
      insert or replace into subreddit_comments
        (subreddit_name, submission_name, name)
        values ('#{subreddit.name}', '#{submission.name}', '#{name}')
    SQL
    return self
  end

  def self.init_table
    @@db.execute <<-SQL
      create table if not exists subreddit_comments (
        subreddit_name varchar(255) references subreddits(name) ON UPDATE CASCADE,
        submission_name varchar(255) references submissions(name) ON UPDATE CASCADE,
        name varchar(255) PRIMARY KEY,
        id varchar(255),
        user_name varchar(255)
      );
    SQL
  end

  protected
  #internal use - see base_reddit.get_from_reddit

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_comments(args)
  end

  def self.constructor_args_for_reddit_object(parent, raw_object)
    { subreddit: parent.subreddit, submission: parent, name: raw_object.fullname, id: raw_object.id, user_name: raw_object.author }
  end

  def self.unique_parent_child(parent, child)
      parent.name + child.name
  end

end
