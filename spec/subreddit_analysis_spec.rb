# require 'minitest/autorun'
# require 'rubygems'
# require 'bundler/setup'
# require 'pry'
# require 'mocha/mini_test'
# require "net/http"
# require 'sqlite3'
#
#
# require File.join(__dir__, '..', 'app', 'subreddit_analysis.rb')
#
# ENV['environment'] = 'test'
#
# describe SubredditAnalysis do
#   before do
#     @subreddit_analysis = SubredditAnalysis.new('spec/fixtures/config.yml')
#     subreddit = JSON.load(File.new("spec/fixtures/funny_subreddit.json"))
#     submission = JSON.load(File.new("spec/fixtures/funny_submitters.json"))
#     @comments = JSON.load(File.new("spec/fixtures/funny_1324234_comments.json"))
#     @subreddit_analysis.db.execute "delete from subreddits"
#     @subreddit_analysis.db.execute "insert into subreddits (name, metadata, ended_at, after) values ('funny', '#{JSON.pretty_generate(subreddit).gsub("'", "''")}', #{submission['ended_at']}, '#{submission['after']}')"
#     @subreddit_analysis.db.execute "delete from subreddit_submissions"
#     @subreddit_analysis.db.execute "insert into subreddit_submissions (subreddit_name, id, ended_at, after)  values ('funny', '1324234', #{@comments['ended_at']}, '#{@comments['after']}')"
#     @subreddit_analysis.db.execute "delete from subreddit_submitters"
#     for submitter in submission["submitters"]
#       @subreddit_analysis.db.execute "insert into subreddit_submitters (subreddit_name, name)  values ('funny', '#{submitter}')"
#     end
#     @subreddit_analysis.db.execute "delete from subreddit_comments"
#     for comment in @comments["comments"]
#       @subreddit_analysis.db.execute "insert into subreddit_comments (subreddit_name, submission_id, name)  values ('funny', '1324234', '#{comment}')"
#     end
#     @users = (@comments['comments'] + submission['submitters']).uniq.sort
#     @subreddit_analysis.db.execute "delete from users"
#     (0..@users.length/2).each do |i|
#       @subreddit_analysis.db.execute "insert or ignore into users (name) values ('#{@users[i]}')"
#     end
#
#     @client = MiniTest::Mock.new
#     @subreddit_analysis.client = @client
#     Redd.stubs(:it).returns(@client)
#   end
#
#   after do
#     @subreddit_analysis.close
#   end
#
#   it "initializes properties" do
#     assert_equal('reddit_bot', @subreddit_analysis.props["username"])
#   end
#
#   it "authorizes" do
#     @client.expect(:authorize!, nil)
#     @subreddit_analysis.authorize
#     assert(@client.verify)
#   end
#
#   describe "read data" do
#     describe "retrieves from data store" do
#       before do
#         @result = @subreddit_analysis.read('funny', 'comments', { 'id' => '1324234'})
#       end
#       it 'matches name' do
#         assert_equal(@comments['name'], @result['name']);
#       end
#       it 'matches ended_at' do
#         assert_equal(@comments['ended_at'], @result['ended_at']);
#       end
#       it 'matches name' do
#         assert_equal(@comments['after'], @result['after']);
#       end
#       it 'matches name' do
#         assert_equal(@comments['id'], @result['id']);
#       end
#       it 'matches name' do
#         assert_equal(@comments['comments'].sort, @result['comments'].sort);
#       end
#     end
#
#     it 'returns default if there is no data store file' do
#       assert_equal({ name: 'foo'}, @subreddit_analysis.read('foo', 'comment', { name: 'foo'}))
#     end
#   end
#
#   describe "comment authors" do
#     before do
#       @comments = [ stub(author: "Je---ja", id: '23456')]
#       @submission = stub(id: '1324234')
#       @subreddit = Subreddit.new
#       @subreddit.name = 'foo'
#       @subreddit.reddit_object = MiniTest::Mock.new
#     end
#
#     it "requests 100 comments if requested" do
#       @subreddit.reddit_object = MiniTest::Mock.new
#       @subreddit.reddit_object.expect(:get_comments, @comments, [{limit: 100, count: 0, after: nil}])
#       @subreddit_analysis.comments(@subreddit, @submission, 100)
#       assert(@subreddit.reddit_object.verify)
#     end
#
#     describe "with saved data" do
#
#       it "uses saved data" do
#         assert_equal(100, @subreddit_analysis.comments(@subreddit, @submission, 100)['ended_at'])
#       end
#
#       it "asks for incremental content" do
#         @subreddit.reddit_object.expect(:get_comments, @comments , [{limit: 100, count: 100, after: "12345"}])
#         assert_equal(200, @subreddit_analysis.comments(@subreddit, @submission, 200)['ended_at'])
#       end
#
#       it "de-dupes" do
#         @subreddit.reddit_object.expect(:get_comments, @comments , [{limit: 100, count: 100, after: "12345"}])
#         assert_equal(86, @subreddit_analysis.comments(@subreddit, @submission, 200)['comments'].length)
#       end
#
#       it "saves last count" do
#         @subreddit.reddit_object.expect(:get_comments, @comments , [{limit: 50, count: 100, after: "12345"}])
#         assert_equal(150, @subreddit_analysis.comments(@subreddit, @submission, 150)['ended_at'])
#       end
#
#       it "slices if requested count is greater than 100" do
#         @subreddit.reddit_object.expect(:get_comments, @comments , [{limit: 100, count: 100, after: "12345"}])
#         @subreddit.reddit_object.expect(:get_comments, @comments , [{limit: 100, count: 200, after: "23456"}])
#         assert_equal(300, @subreddit_analysis.comments(@subreddit, @submission, 300)['ended_at'])
#       end
#
#     end
#   end
#
#   describe "subreddit submissions" do
#     before do
#       @submissions = [ stub(author: "Je---ja", id: '23456', get_new: [])]
#       @subreddit = stub(name: 'foo', reddit_object: stub())
#       @subreddit_analysis.stubs(comments: nil) #save: nil,
#     end
#
#     it "requests 100 submissions if requested" do
#       @subreddit.reddit_object.expect(:get_new, @submissions, [{limit: 100, count: 0, after: nil}])
#       @subreddit_analysis.submissions(@subreddit, 100)
#       assert(@subreddit.verify)
#     end
#
#     describe "with saved data" do
#
#       it "uses saved data" do
#         assert_equal(100, @subreddit_analysis.submissions(@subreddit, 100)['ended_at'])
#       end
#
#       it "asks for incremental content" do
#         @subreddit.reddit_object.expect(:get_new, @submissions , [{limit: 100, count: 100, after: "54wmuj"}])
#         assert_equal(200, @subreddit_analysis.submissions(@subreddit, 200)['ended_at'])
#       end
#
#       it "de-dupes" do
#         @subreddit.reddit_object.expect(:get_new, @submissions , [{limit: 100, count: 100, after: "54wmuj"}])
#         assert_equal(6, @subreddit_analysis.submissions(@subreddit, 200)['submitters'].length)
#       end
#
#       it "saves last count" do
#         @subreddit.reddit_object.expect(:get_new, @submissions , [{limit: 50, count: 100, after: "54wmuj"}])
#         assert_equal(150, @subreddit_analysis.submissions(@subreddit, 150)['ended_at'])
#       end
#
#       it "slices if requested count is greater than 100" do
#         @subreddit.reddit_object.expect(:get_new, @submissions , [{limit: 100, count: 100, after: "54wmuj"}])
#         @subreddit.reddit_object.expect(:get_new, @submissions , [{limit: 100, count: 200, after: "23456"}])
#         assert_equal(300, @subreddit_analysis.submissions(@subreddit, 300)['ended_at'])
#       end
#
#     end
#
#   end
# end
