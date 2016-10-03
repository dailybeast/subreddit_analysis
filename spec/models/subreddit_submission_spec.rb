require 'minitest/autorun'
require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'mocha/mini_test'
require "net/http"
require 'sqlite3'


require File.join(__dir__, '..', '..', 'app', 'models', 'subreddit')
require File.join(__dir__, '..', '..', 'app', 'models', 'subreddit_submission')
require File.join(__dir__, '..', '..', 'app', 'models', 'subreddit_comment')

ENV['environment'] = 'test'

describe SubredditSubmission do
  before do
    @db = SQLite3::Database.new File.join(__dir__, '..', 'fixtures', 'subreddit_analysis_test.db')
    @client = MiniTest::Mock.new
    @client.expect(:subreddit_from_name, stub(display_name: 'funny', to_json: { display_name: 'funny' }.to_json), ['funny'])
    Subreddit.connections(@db)
    Subreddit.init_table
    SubredditSubmission.init_table
    SubredditComment.init_table
  end

  after do
    Subreddit.destroy_table
    SubredditSubmission.destroy_table
    SubredditComment.destroy_table
    @db.close
  end

  describe "saves" do
    before do
      @subreddit = Subreddit.new(name: 'funny').save
      @submission = SubredditSubmission.new({id: 'qei425', name: 'foo', subreddit: @subreddit})
      @comment = SubredditComment.new({ subreddit: @subreddit, name: 'Bob', submission: @submission })
      @submission.comments = [@comment]
      @submission.save
    end
    it "saves" do
      assert_equal("qei425", @db.execute("select id from subreddit_submissions where subreddit_name='funny';").first.first)
    end
    it "cascade saves comments" do
      assert_equal(1, @db.execute("select count(*) from subreddit_comments where subreddit_name='funny';").first.first)
    end
  end

  describe "find_for" do
    before do
      @subreddit = Subreddit.new(name: 'funny').save
      SubredditSubmission.new(name: 'funny', subreddit: @subreddit).save
    end

    it "finds by subreddit " do
      assert_equal(1, SubredditSubmission.find_for(@subreddit).length)
    end
  end

  describe "finds unique_submitters_for" do
    before do
      @subreddit = Subreddit.new(name: 'funny').save
      SubredditSubmission.new(subreddit: @subreddit, name: 'foo', user_name: 'foo_user').save
      SubredditSubmission.new(subreddit: @subreddit, name: 'foo2', user_name: 'foo_user').save
      SubredditSubmission.new(subreddit: @subreddit, name: 'bar', user_name: 'bar_user').save
    end
    it "removes dups" do
      assert_equal(['bar_user', 'foo_user'], SubredditSubmission.unique_submitters_for(@subreddit).sort)
    end
  end

  describe "get_comments" do
    before do
      reddit_comment = stub(subreddit: 'foo_subreddit',
                                id: 'qey44v',
                                author: 'bar_author',
                                fullname: "new_comment_name")
      reddit_dub_comment = stub(subreddit_name: 'foo_subreddit',
                                    id: 'tu3023',
                                    author: 'dup_author',
                                    fullname: 'existing_comment_name')
      @reddit_object = MiniTest::Mock.new
      @reddit_object.expect(:nil?, false)
      @reddit_object.expect(:get_comments,
                              [reddit_comment, reddit_dub_comment],
                              [{limit: 100, count: 10, after: 'bar'}])
      @subreddit = Subreddit.new(name: 'funny', reddit_object: @reddit_object)
      @subreddit_submission = SubredditSubmission.new(name: 'funny', subreddit: @subreddit)
      @subreddit_submission.comments = [
                                  SubredditComment.new(subreddit_name: 'foo_subreddit',
                                                          user_name: 'dup_author',
                                                          id: 'tu3023',
                                                          name: 'existing_comment_name',
                                                          submission: @subreddit_submission)]
      @subreddit_submission.reddit_object = @reddit_object
      @subreddit_submission.after = 'bar'
      @subreddit_submission.get_comments(100, 10)
    end
    it "gets comments from reddit" do
      assert(@reddit_object.verify)
    end
    it "uniques the list" do
      assert_equal(2, @subreddit_submission.comments.length)
    end
    it "increments ended at" do
      assert_equal(100, @subreddit_submission.ended_at)
    end
    it "sets after" do
      assert_equal('existing_comment_name', @subreddit_submission.after)
    end
  end
end
