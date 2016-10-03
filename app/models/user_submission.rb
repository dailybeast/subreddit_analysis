require_relative 'base'

class UserSubmission < BaseUserActivity
  protected

  def self.reddit_accessor(reddit_object, args)
    reddit_object.get_submissions(args)
  end

end
