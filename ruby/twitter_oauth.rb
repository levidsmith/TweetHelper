###
#
# TwitterOAuth (twitter_oauth.rb)
# 2017 Levi D. Smith - @GaTechGrad
#
###

require 'oauth'
require 'json'
require 'fileutils'
require 'date'

$consumer_key = ""
$consumer_secret = ""
$oauth_token = ""
$oauth_token_secret = ""

LOOKUP_SLEEP_INTERVAL = 61
REQUEST_SLEEP_INTERVAL = 10
$iSleepInterval = LOOKUP_SLEEP_INTERVAL


$access_token = nil

SLEEP_MIN = 60
SLEEP_MAX = 70

FOLLOWERS_LIMIT = 50
FOLLOW_RATIO_LIMIT = 200
LAST_ACTION_LIMIT = 5

USERS_PER_CURSOR_PAGE = 5000
GOOD_LIST_MAX = 250

GOODLIST_FILENAME = "goodlist.txt"

def readTokens()
  f = File.new("tokens.txt", "r")
  $consumer_key = f.gets().chomp()
  $consumer_secret = f.gets().chomp()
  $oauth_token = f.gets().chomp()
  $oauth_token_secret = f.gets().chomp()
  f.close
end

# Code from Twitter developer examples
# Exchange your oauth_token and oauth_token_secret for an AccessToken instance.
def prepare_access_token(oauth_token, oauth_token_secret)
    consumer = OAuth::Consumer.new($consumer_key, $consumer_secret, { :site => "https://api.twitter.com", :scheme => :header })
     
    # now create the access token object from passed values
    token_hash = { :oauth_token => oauth_token, :oauth_token_secret => oauth_token_secret }
    $access_token = OAuth::AccessToken.from_hash(consumer, token_hash )
 
end


def displayHomeTweets() 
  # use the access token as an agent to get the home timeline
  response = $access_token.request(:get, "https://api.twitter.com/1.1/statuses/home_timeline.json")

  puts response
  #puts response["followers_count"]

  i = 0
  tweets = JSON.parse(response.body)
  tweets.map do | tweet |
    if (i < 10)
#      puts i.to_s + ": User: " + tweet["user"]["name"] + " " + "Tweet: " + tweet["text"]
      puts " " + "Tweet: " + tweet["text"]
    end
  i += 1
  end
end



def followUser(username) 
  #Follow user
  puts "Following #{username}"

  response = $access_token.request(:post, "https://api.twitter.com/1.1/friendships/create.json?screen_name=#{username}&follow=true")
  puts response

end

def followGoodList()
  arrayGoodList = Array.new()
  File.open(GOODLIST_FILENAME).each do |line|
    arrayGoodList << line.chomp()
  end

  arrayGoodList.each { |username|

    puts "Following #{username}"

    response = $access_token.request(:post, "https://api.twitter.com/1.1/friendships/create.json?screen_name=#{username}&follow=true")
    puts response
    iSleep = SLEEP_MIN + rand(SLEEP_MAX - SLEEP_MIN)
    puts "Sleeping for #{iSleep} seconds"
    sleep(iSleep)
  }

  archiveGoodList()

end

def archiveGoodList()
  strArchiveFile = "#{GOODLIST_FILENAME}" + Time.now.strftime("%Y%m%d_%H%M%S") + ".txt"
  puts "Moving #{GOODLIST_FILENAME} to #{strArchiveFile}"
  if (!File.directory?("./archives"))
    FileUtils.mkdir "./archives"
  end
  FileUtils.mv(GOODLIST_FILENAME, "./archives/" + strArchiveFile) 

end

def makeGoodListCursor(username)
  cursor_id = makeGoodList(username, -1)
  sleep(REQUEST_SLEEP_INTERVAL)

  while(cursor_id != 0)
    puts "Making list for cursor page #{cursor_id}"
    cursor_id = makeGoodList(username, cursor_id)
    sleep(REQUEST_SLEEP_INTERVAL)
  
  end

end

def makeGoodList(username, cursorID)

  puts "Making #{GOODLIST_FILENAME} for #{username}"

  #read the checked.txt file into an array
  arrayChecked = Array.new
  if File.file?("checked.txt")
    File.open("checked.txt").each do |line|
    arrayChecked << line.chomp().to_i
    end
  end

  # use the access token as an agent to get the home timeline
  response = $access_token.request(:get, "https://api.twitter.com/1.1/followers/ids.json?cursor=#{cursorID}&screen_name=#{username}&count=#{USERS_PER_CURSOR_PAGE}")

  puts response
  #puts response["followers_count"]


#  puts "RESULT: " + JSON.parse(response.body)
  users = JSON.parse(response.body)
#  puts users["next_cursor"]
  puts users["ids"]
  users["ids"].each do |id|
    if (getGoodListCount() >= GOOD_LIST_MAX)
      puts "Reached Good List Max (#{GOOD_LIST_MAX})"
      exit
    end

    if (arrayChecked.include?(id))
      puts "Skipping #{id} - in checked.txt"
    else
      if (isGoodPerson(id))
        puts "ID: #{id}"
        f = File.open(GOODLIST_FILENAME, "a+")
        f.puts "#{id}"
        f.close
      else
        puts "Skipping #{id} - !isGoodPerson"
      end

#Not in the checked file, so add them
      fChecked = File.open("checked.txt", "a+")
      fChecked.puts "#{id}" 
      fChecked.close

      puts "Sleeping for #{$iSleepInterval}"
      sleep($iSleepInterval)

    end


  end


  puts "next_cursor: #{users["next_cursor"]}"
  return users["next_cursor"]

end

def displayUserID(username)
    response = $access_token.request(:get, "https://api.twitter.com/1.1/users/lookup.json?screen_name=#{username}")
    user = JSON.parse(response.body)
#    puts user
    uid = ""
    uid = user[0]["id"]

    user[0].map do |k, v|
      puts "Key: #{k} Value: #{v}"
    end
    puts "ID: #{uid}"

end

def isGoodPerson(user_id) 
  isGood = TRUE
  $iSleepInterval = LOOKUP_SLEEP_INTERVAL 

  response = $access_token.request(:get, "https://api.twitter.com/1.1/users/lookup.json?user_id=#{user_id}")
  user = JSON.parse(response.body)

  if (user.class == Hash && !user["errors"].nil?)
    puts "ERROR getting user #{user_id}"
    return false
  end

  u_screen_name = user[0]["screen_name"]
  puts "Handle: #{u_screen_name}"
  
  u_followers = user[0]["followers_count"]
  puts "Followers: #{u_followers}"
  if (u_followers < FOLLOWERS_LIMIT) 
    puts "Follower Count failed (#{u_followers} < #{FOLLOWERS_LIMIT})"
  end
  
  u_following = user[0]["friends_count"]
  puts "Following: #{u_following}"

  if (u_following > 0)
    u_following_ratio = (u_followers.to_f / u_following.to_f * 100.to_f).to_i
    puts "Follow ratio: #{u_following_ratio}"

    if (u_following_ratio > FOLLOW_RATIO_LIMIT)
      puts "Follower Ratio failed (#{u_following_ratio} > #{FOLLOW_RATIO_LIMIT})"
    end
  end


  if (!user[0]["status"].nil?)
    u_last_action = user[0]["status"]["created_at"]
    lastActionDate = DateTime.strptime(u_last_action, "%a %b %d %H:%M:%S %z %Y")  
    puts "Last action: #{u_last_action}"

    todayDate = DateTime.now
    puts lastActionDate
    puts todayDate 

    days_since_last_action = (todayDate - lastActionDate).to_i
    puts "Date: #{lastActionDate} Diff: #{days_since_last_action }"

    if (days_since_last_action > LAST_ACTION_LIMIT)
      puts "Last action failed (#{days_since_last_action} > #{LAST_ACTION_LIMIT})"
    end

  else
    days_since_last_action = 9999
  end

  if (u_followers > FOLLOWERS_LIMIT && u_following_ratio < FOLLOW_RATIO_LIMIT && days_since_last_action < LAST_ACTION_LIMIT)
    isGood = TRUE
  else
    isGood = FALSE
    $iSleepInterval = REQUEST_SLEEP_INTERVAL 
  end 

  if (isGood)
    response1 = $access_token.request(:get, "https://api.twitter.com/1.1/friendships/lookup.json?user_id=#{user_id}")
    connections = JSON.parse(response1.body)
    puts connections
    connections[0]["connections"].each { |value|
      puts "Value: #{value}"
      if (value == "following" || value == "followed_by")
        isGood = FALSE
        puts "Already following"
      end
    } 
      

  end

  puts "*** #{u_screen_name} isGoodUser? #{isGood}" 
  
  return isGood 
end

def followGoodListByID()
  arrayGoodList = Array.new()
  File.open(GOODLIST_FILENAME).each do |line|
    arrayGoodList << line.chomp()
  end


  i = 1
  iCount = arrayGoodList.count
  arrayGoodList.each { |userid|

    puts "Following #{userid} #{i} of #{iCount}"

    response = $access_token.request(:post, "https://api.twitter.com/1.1/friendships/create.json?user_id=#{userid}&follow=true")
    puts response
    iSleep = SLEEP_MIN + rand(SLEEP_MAX - SLEEP_MIN)
    puts "Sleeping for #{iSleep} seconds"
    sleep(iSleep)
    i += 1
  }

   archiveGoodList()
end

def showRateLimit()
  # use the access token as an agent to get the home timeline
  response = $access_token.request(:get, "https://api.twitter.com/1.1/application/rate_limit_status.json?resources=help,users,search,statuses,friendships,application")

  puts response

  limits = JSON.parse(response.body)


#  if FALSE
  if TRUE
    limits["resources"].map do | limit_category |
      limit_category.map do |t|
       puts "t: #{t}"
       puts
      end
    end
  end

#  puts "Lookup - limit: #{limits["resources"]["users"]["/users/lookup"]["limit"]} remaining: #{limits["resources"]["users"]["/users/lookup"]["remaining"]}"


  h = limits["resources"]["users"]["/users/lookup"]
  puts "/users/lookup - limit: #{h["limit"]} remaining: #{h["remaining"]}"

  h = limits["resources"]["statuses"]["/statuses/home_timeline"]
  puts "/statuses/home_timeline - limit: #{h["limit"]} remaining: #{h["remaining"]}"

  h = limits["resources"]["statuses"]["/statuses/show/:id"]
  puts "/statuses/show:id - limit: #{h["limit"]} remaining: #{h["remaining"]}"
  
  h = limits["resources"]["friendships"]["/friendships/lookup"]
  puts "/friendships/lookup - limit: #{h["limit"]} remaining: #{h["remaining"]}"
  
  h = limits["resources"]["application"]["/application/rate_limit_status"]
  puts "/application/rate_limit_status - limit: #{h["limit"]} remaining: #{h["remaining"]}"
  
  

  
end

def getGoodListCount()
  iCount = -1

  if (File.exist?(GOODLIST_FILENAME))
    f = File.open(GOODLIST_FILENAME)
    iCount = f.count
    puts "Good list count: #{iCount}"
    f.close()
  end
  
  return iCount 

end

def displayUsage() 
    puts "Usage: ruby twitter_oauth.rb <command> <options>"
    puts "Commands:" 
    puts "hometweets - list tweets in your timeline"
    puts "follow <username> - follows the specified user"
    puts "followgoodlist    - follows all IDs in #{GOODLIST_FILENAME} file"
    puts "followgoodlistusername  - follows all handles in #{GOODLIST_FILENAME} file"
    puts "makegoodlist <username>  - creates #{GOODLIST_FILENAME} file of IDs using followers of the specified user"

    puts "ratelimit - display rate limit information"
    puts "goodlistcount - how many people are in the good list"
    puts "getuserid <username> - return the ID for the specified handle"
    puts "isgoodperson <user_id> - returns if the specified user_id is a good person"
end


def main()
  readTokens()
 
  prepare_access_token($oauth_token, $oauth_token_secret)

  if (ARGV.count == 0) 
    displayUsage()
  elsif (ARGV[0].upcase == "HOMETWEETS") 
    displayHomeTweets() 
  elsif (ARGV[0].upcase == "FOLLOW") 
    followUser(ARGV[1]) 
  elsif (ARGV[0].upcase == "FOLLOWGOODLIST") 
      followGoodListByID()
  elsif (ARGV[0].upcase == "FOLLOWGOODLISTUSERNAME") 
      followGoodList()
  elsif (ARGV[0].upcase == "MAKEGOODLIST") 
    if (ARGV.count == 2)
      makeGoodListCursor(ARGV[1])
    else 
      displayUsage()
    end
  elsif (ARGV[0].upcase == "RATELIMIT") 
    showRateLimit() 
  elsif (ARGV[0].upcase == "GOODLISTCOUNT") 
    getGoodListCount() 
  elsif (ARGV[0].upcase == "GETUSERID") 
    if (ARGV.count == 2)
      displayUserID(ARGV[1]) 
    else 
      displayUsage()
    end
  elsif (ARGV[0].upcase == "ISGOODPERSON") 
    if (ARGV.count == 2)
      puts isGoodPerson(ARGV[1]) 
    else 
      displayUsage()
    end
  else 
    puts "Invalid option"
    displayUsage()
  end



end

main()

