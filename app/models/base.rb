class Base
  def initialize(props = {})
    props.each { |name, value| instance_variable_set("@#{name}", value) }
  end

  def self.quote(s)
    if s.nil?
      return 'null'
    elsif s.is_a? Numeric
      return s
    else
      return "'#{s.gsub("'", "''")}'"
    end
  end
  def quote(s)
    Base.quote(s)
  end

  def self.connections(db)
    @@db = db
  end

  def self.reddit_client(reddit_client)
    @@reddit_client = reddit_client
  end

  def self.find_one(query)
    rows = @@db.execute(query)
    if rows && rows.length > 0
      row = rows.first
    end
    return row
  end

  def self.destroy_table
    begin
      @@db.execute "drop table #{self.tablename}"
    rescue
      #noop
    end
  end

  def self.tablename
    t = self.name.downcase
    t.gsub!(/^user(\w)/, 'user_\1')
    t.gsub!(/^subreddit(\w)/, 'subreddit_\1')
    t += 's'
    return t
  end

end
