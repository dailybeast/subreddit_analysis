require 'minitest/autorun'
require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'mocha/mini_test'
require "net/http"
require 'sqlite3'


require File.join(__dir__, '..', '..', 'app', 'models', 'user')
require File.join(__dir__, '..', '..', 'app', 'models', 'user_Submission')
require File.join(__dir__, '..', '..', 'app', 'models', 'user_submission')

ENV['environment'] = 'test'

describe User do
  before do
    @db = SQLite3::Database.new File.join(__dir__, '..', 'fixtures', 'subreddit_analysis_test.db')
    @client = MiniTest::Mock.new
    @client.expect(:user_from_name, stub(name: 'foo', to_json: { name: 'foo' }.to_json), ['foo'])
    User.connections(@db)
    User.init_table
  end

  after do
    User.destroy_table
    @db.close
  end

  describe "new instance" do
    before do
      @user = User.new
      @user.name = 'foo'
    end

    it "lazy loads reddit_object" do
      @user.reddit_client = @client
      @user.reddit_object
      assert(@client.verify)
    end

    it "default submitted_ended_at to 0" do
      assert_equal(0, @user.submissions_ended_at)
    end

    it "default comments_ended_at to 0" do
      assert_equal(0, @user.comments_ended_at)
    end

    it "saves" do
      @user.save
      assert_equal(1, @db.execute("select count(*) from users;").first.first)
    end

    describe "cascade save" do
      before do
        UserComment.init_table
        UserSubmission.init_table
        @user.comments = [UserComment.new(user: @user, subreddit_name: 'funny')]
        @user.submissions = [UserSubmission.new(user: @user, subreddit_name: 'funny')]
        @user.save
      end
      after do
        UserComment.destroy_table
        UserSubmission.destroy_table
      end

      it "cascade saves comments" do
        assert_equal(1, @db.execute("select count(*) from user_comments where user_name='#{@user.name}';").first.first)
      end

      it "cascade saves submissions" do
        assert_equal(1, @db.execute("select count(*) from user_submissions where user_name='#{@user.name}';").first.first)
      end

    end

    describe "get_comments" do
      before do
        mock_comment = stub(subreddit: 'foo_subreddit', fullname: 'qey44v')
        @reddit_object = MiniTest::Mock.new
        @reddit_object.expect(:nil?, false)
        @reddit_object.expect(:get_comments, [mock_comment], [{limit: 100, count: 10, after: 'bar'}])
        @user.comments = [UserComment.new(user: @user, subreddit_name: 'foo_subreddit')]
        @user.reddit_object = @reddit_object
        @user.comments_after = 'bar'
        @user.get_comments(100, 10)
      end
      it "gets comments from reddit" do
        assert(@reddit_object.verify)
      end
      it "uniques the list" do
        assert_equal(1, @user.comments.length)
      end
      it "increments ended at" do
        assert_equal(100, @user.comments_ended_at)
      end
      it "sets after" do
        assert_equal('qey44v', @user.comments_after)
      end
    end

    describe "get_submissions" do
      before do
        mock_submission = stub(subreddit: 'foo_subreddit', fullname: 'qey44v')
        @reddit_object = MiniTest::Mock.new
        @reddit_object.expect(:nil?, false)
        @reddit_object.expect(:get_submissions, [mock_submission], [{limit: 100, count: 10, after: 'bar'}])
        @user.submissions = [UserSubmission.new(user: @user, subreddit_name: 'foo_subreddit')]
        @user.reddit_object = @reddit_object
        @user.submissions_after = 'bar'
        @user.get_submissions(100, 10)
      end
      it "gets submissions from reddit" do
        assert(@reddit_object.verify)
      end
      it "uniques the list" do
        assert_equal(1, @user.submissions.length)
      end
      it "increments ended at" do
        assert_equal(100, @user.submissions_ended_at)
      end
      it "sets after" do
        assert_equal('qey44v', @user.submissions_after)
      end
    end
  end

  describe 'create' do
    before do
      User.create('foo', @client)
    end
    it "finds user_from_name" do
      assert(@client.verify)
    end
    it "creates database" do
      assert(@db.execute("select count(*) from users where name = 'foo';").first.first == 1)
    end
  end

  describe 'find' do
    before do
      UserComment.init_table
      UserSubmission.init_table
      user = User.create('foo', @client)
      UserSubmission.create(user, 'foo_subreddit')
      UserComment.create(user, 'foo_subreddit')
      @user = User.find('foo', @client)
    end
    after do
      UserComment.destroy_table
      UserSubmission.destroy_table
    end

    it "finds user by name" do
      assert_equal('foo', @user.name)
    end

    it "finds existing comments" do
      assert_equal(1, @user.comments.length)
    end

    it "finds existing submissions" do
      assert_equal(1, @user.submissions.length)
    end
  end

  it "inits db" do
    assert(@db.execute("select count(*) from users;").first.first == 0)
  end


end
