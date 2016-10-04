require 'minitest/autorun'
require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'mocha/mini_test'
require "net/http"
require 'sqlite3'
require 'csv'


require File.join(__dir__, '..', 'app', 'subreddit_analysis.rb')

ENV['environment'] = 'test'

describe SubredditAnalysis do
  before do
    @subreddit_analysis = SubredditAnalysis.new('spec/fixtures/config.yml')
    @client = MiniTest::Mock.new
    Redd.stubs(:it).returns(@client)
    db_seed
    @subreddit = Subreddit.find('funny')
  end

  after do
    db_drop
    @subreddit_analysis.close
  end

  it "initializes properties" do
    assert_equal('reddit_bot', @subreddit_analysis.props["username"])
  end

  it "authorizes" do
    @client.expect(:authorize!, nil)
    @subreddit_analysis.authorize
    assert(@client.verify)
  end

  describe "crawl_subreddit_submissions" do
    before do
      @client.expect(:authorize, nil)
      reddit_object = MiniTest::Mock.new
      @subreddit.reddit_object.expect(:nil?, false)
      @subreddit.reddit_object.expect(:nil?, false)
      @subreddit.reddit_object.expect(:nil?, false)
      @subreddit.reddit_object = reddit_object
    end
    it "gets does not request new submissions when there are already enough in the db" do
      @subreddit_analysis.crawl_subreddit_submissions(@subreddit, 1)
      assert(@subreddit.reddit_object.verify)
    end
    it "gets additional new submissions up to limit" do
      @subreddit.reddit_object.expect(:get_new, [], [{:limit => 8, :count => 2, :after => 't3_55owj3'}])
      @subreddit_analysis.crawl_subreddit_submissions(@subreddit, 10)
      assert(@subreddit.reddit_object.verify)
    end
  end

  def db_drop
    Subreddit.destroy_table
    SubredditSubmission.destroy_table
    SubredditComment.destroy_table
    User.destroy_table
    UserComment.destroy_table
    UserSubmission.destroy_table
  end

  def db_seed
    json = File.read(File.join(__dir__, '..', 'spec', 'fixtures', 'funny_subreddit.json'))
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'subreddit.csv'), { col_sep: '|' }) do |row|
      Subreddit.new({
        name: row[0],
        ended_at: row[1],
        after: row[2],
        metadata: json.gsub("'", "''")
        }).save
    end
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'subreddit_submission.csv'), { col_sep: '|' }) do |row|
      SubredditSubmission.new({
        subreddit: stub(name: row[0]),
        name: row[1],
        id: row[2],
        user_name: row[3],
        ended_at: row[4],
        after: row[5]
        }).save
    end
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'subreddit_comment.csv'), { col_sep: '|' }) do |row|
      SubredditComment.new({
        subreddit: stub(name: row[0]),
        submission: stub(name: row[1], comments: []),
        name: row[2],
        id: row[3],
        user_name: row[4]
        }).save
    end
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'user.csv'), { col_sep: '|' }) do |row|
      User.new({
        name: row[0],
        metadata: "{ 'foo': 'bar' }",
        submissions_ended_at: row[2],
        submissions_after: row[3],
        comments_ended_at: row[4],
        comments_after: row[5]
        }).save
    end
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'user_submission.csv'), { col_sep: '|' }) do |row|
      User.new({
        user_name: row[0],
        subreddit_name: row[1],
        }).save
    end
    CSV.foreach(File.join(__dir__, '..', 'spec', 'fixtures', 'user_comment.csv'), { col_sep: '|' }) do |row|
      User.new({
        user_name: row[0],
        subreddit_name: row[1],
        }).save
    end

  end

end
