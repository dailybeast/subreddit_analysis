require_relative 'base'

class SubredditComment < Base
  attr_accessor :subreddit, :submission, :name
  def initialize(props = {})
    super
    unless (submission.comments.include?(self))
      submission.comments.push(self)
    end
  end

  def save
    @@db.execute <<-SQL
      insert or replace into subreddit_comments
        (subreddit_name, submission_id, name)
        values ('#{subreddit.name}', '#{submission.id}', '#{name}')
    SQL
    return self
  end

  def self.init_table
    @@db.execute <<-SQL
      create table if not exists subreddit_comments (
        subreddit_name varchar(255) references subreddits(name) ON UPDATE CASCADE,
        submission_id varchar(255) references submissions(id) ON UPDATE CASCADE,
        name varchar(255),
        PRIMARY KEY (submission_id, name)
      );
    SQL
  end

  protected
  #internal use - see base_reddit.get_from_reddit

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_comments(args)
  end

  def self.constructor_args_for_reddit_object(parent, raw_object)
    { subreddit: parent.subreddit, submission: parent, name: raw_object.author }
  end

  def self.unique_parent_child(parent, child)
    parent.id + child.name
  end

end
