#SubredditAnalysis (Ruby)

**A Ruby implementation based on but not a direct port of [RedditAnalysisBot](https://github.com/SirNeon618/SubredditAnalysis) by [SirNeon](https://www.reddit.com/user/SirNeon)**

###Requirements
------------
* Python 2.3.1
* [redd](https://github.com/avinashbot/redd)
* Sqlite3

###Install Dependencies
* Clone the repo
* bundle install
* create a config.yml in config based on the example pointing to your Reddit script app credentials

###Test
* Uses minitest and mocha
* bundle exec rake test

###Run The Bot
  `./bin/run_subreddit_analysis [subreddit_name e.g. askreddit]`
  
###Configuration Options
* user_agent: [should be descriptive and reference your user name]
* data_folder: [where to put the sqlite db file]
* submission_limit: [how many submissions to crawl for the selected subreddit]
* comment_limit: [how many comments to crawl for each submission]
* user_activity_limit: [how many comments and submissions to crawl for each user who submitted or commented to the seleced subreddit]

###Dealing with Reddit rate limiting
* The bot tries to honor the timeout provided via redd on errors but otherwise sleeps for a set period before retrying

###Results
* Are dropped into a csv file in a reports folder titled by date and subreddit
* File has a simple count of the number of different submitters and 
  commenters of the selected subreddit also submitted or commented into another subreddit
  
|count|subreddit
--- | --- 
AskReddit|12711
funny|6543
pics|6089
todayilearned|5690
Showerthoughts|5228
gaming|5055
videos|4530
gifs|4129
news|3907
