require_relative 'base'

class BaseUserActivity < Base
  attr_accessor :user, :subreddit_name

  def save
    @@db.execute <<-SQL
    insert or replace into #{Object.const_get(self.class.name).tablename} (user_name, subreddit_name)
      values ('#{user.name}', '#{subreddit_name}');
    SQL
    return self
  end

  def self.create(user, subreddit_name)
    return Object.const_get(self.name).new({user: user, subreddit_name: subreddit_name}).save
  end

  def self.find_for(user)
    list = []
    subreddit_names = @@db.execute("select distinct(subreddit_name) from #{tablename} where user_name = '#{user.name}' collate nocase;")
    for row in subreddit_names do
      list.push(Object.const_get(self.name).new({user: user, subreddit_name: row[0]}))
    end
    return list
  end

  def self.init_table
    @@db.execute <<-SQL
      create table if not exists #{tablename} (
        user_name varchar(255)  references users(name) ON UPDATE CASCADE,
        subreddit_name varchar(255),
        primary key (user_name, subreddit_name)
      );
    SQL
  end

  protected
  #internal use - see base_reddit.get_from_reddit
  def self.constructor_args_for_reddit_object(parent, raw_object)
    { user: parent, subreddit_name: raw_object.subreddit}
  end

  def self.unique_parent_child(parent, child)
    parent.name + child.subreddit_name
  end

end
