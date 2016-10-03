require_relative 'base_user_activity'

class UserComment < BaseUserActivity
  protected

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_comments(args)
  end
end
