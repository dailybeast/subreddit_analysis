require_relative 'base'

class UserSubmission < BaseUserActivity
  protected

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_submitted(args)
  end

end
