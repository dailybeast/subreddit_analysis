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

describe Subreddit do
  before do
    @db = SQLite3::Database.new File.join(__dir__, '..', 'fixtures', 'subreddit_analysis_test.db')
    @client = MiniTest::Mock.new
    @client.expect(:subreddit_from_name, stub(display_name: 'funny', to_json: { display_name: 'funny' }.to_json), ['funny'])
    Subreddit.connections(@db)
    Subreddit.reddit_client(@client)
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

  describe "new instance" do
    before do
      @subreddit = Subreddit.new(name: 'funny')
    end

    it "lazy loads reddit_object" do
      @subreddit.reddit_object
      assert(@client.verify)
    end

    it "default ended_at to 0" do
      assert_equal(0, @subreddit.ended_at)
    end
    describe "saves" do
      before do
        @subreddit.metadata = "{'foo' : 'bar'}"
        @submission = SubredditSubmission.new({id: 'qei425', name: 'foo', subreddit: @subreddit})
        @comment = SubredditComment.new({ subreddit: @subreddit, name: 'Bob', submission: @submission })
        @submission.comments = [@comment]
        @subreddit.submissions = [@submission]
        @subreddit.save
      end
      it "saves" do
        assert_equal("{'foo' : 'bar'}", @db.execute("select metadata from subreddits where name='funny';").first.first)
      end
      it "cascade saves submissions" do
        assert_equal(1, @db.execute("select count(*) from subreddit_submissions where subreddit_name='funny';").first.first)
      end
      it "cascade saves comments" do
        assert_equal(1, @db.execute("select count(*) from subreddit_comments where submission_name='foo';").first.first)
      end
    end
  end

  describe "get_submissions" do
    before do
      @subreddit = Subreddit.new(name: 'funny')
      reddit_submission = stub(subreddit: 'foo_subreddit',
                                id: 'qey44v',
                                author: 'bar_author',
                                fullname: "new_submission_name")
      reddit_dub_submission = stub(subreddit_name: 'foo_subreddit',
                                    id: 'tu3023',
                                    author: 'dup_author',
                                    fullname: 'existing_submission_name')
      @reddit_object = MiniTest::Mock.new
      @reddit_object.expect(:nil?, false)
      @reddit_object.expect(:get_new,
                              [reddit_submission, reddit_dub_submission],
                              [{limit: 100, count: 10, after: 'bar'}])
      @subreddit.submissions = [
                                  SubredditSubmission.new(subreddit_name: 'foo_subreddit',
                                                          id: 'tu3023',
                                                          name: 'existing_submission_name')]
      @subreddit.reddit_object = @reddit_object
      @subreddit.after = 'bar'
      @subreddit.get_submissions(100, 10)
    end
    it "gets submissions from reddit" do
      assert(@reddit_object.verify)
    end
    it "uniques the list" do
      assert_equal(2, @subreddit.submissions.length)
    end
    it "increments ended at" do
      assert_equal(100, @subreddit.ended_at)
    end
    it "sets after" do
      assert_equal('existing_submission_name', @subreddit.after)
    end
  end

  describe "finds" do
    before do
      subreddit = Subreddit.new(name: 'funny').save
      SubredditSubmission.new({id: 'qei425', name: 'foo', subreddit: subreddit}).save
      @subreddit = Subreddit.find('funny')
    end

    it "subreddit" do
      assert(!Subreddit.find('funny').nil?)
    end
    it "subreddit submissions" do
      assert_equal(1, Subreddit.find('funny').submissions.length)
    end

  end

  describe "unique_submitters_and_commenters" do
    before do
      @subreddit = Subreddit.new(name: 'funny').save
      s1 = SubredditSubmission.new(subreddit: @subreddit, name: 'foo', user_name: 'foo_user').save
      s2 =SubredditSubmission.new(subreddit: @subreddit, name: 'foo2', user_name: 'foo_user').save
      s3 = SubredditSubmission.new(subreddit: @subreddit, name: 'bar', user_name: 'bar_user').save
      SubredditComment.new(subreddit: @subreddit, submission: s1, name: 'foo', user_name: 'foo_comment_user').save
      SubredditComment.new(subreddit: @subreddit, submission: s3, name: 'foo2', user_name: 'foo_user').save
      SubredditComment.new(subreddit: @subreddit, submission: s1, name: 'bar', user_name: 'bar_comment_user').save
    end

    it "removes dups" do
      assert_equal(['bar_comment_user', 'bar_user', 'foo_comment_user', 'foo_user'], @subreddit.unique_submitters_and_commenters.sort)
    end

  end

  it "inits db" do
    assert(@db.execute("select count(*) from subreddits;").first.first == 0)
  end


  describe 'create' do
    before do
      Subreddit.create('funny')
    end
    it "finds subreddit_from_name" do
      assert(@client.verify)
    end
    it "creates database" do
      assert(@db.execute("select count(*) from subreddits where name = 'funny';").first.first == 1)
    end
  end
end
