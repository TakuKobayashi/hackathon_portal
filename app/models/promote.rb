module Promote
  # 7日以上前にフォローしたけどフォロー返しされていなければフォローをするのをやめる
  EFFECTIVE_PROMOTE_FILTER_SECOND = 7 * 24 * 60 * 60

  def self.table_name_prefix
    'promote_'
  end

  def self.long_twitter_promote!
    self.like_major_user!
    self.import_bot_followers!
  end

  def self.twitter_promote_action!
    self.try_follows!
    self.organize_follows!
  end

  # とある内容について呟いているツイート全て影響力が大きい人を中心にいいねする
  def self.like_major_user!
    twitter_client = TwitterBot.get_twitter_client(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    fail_counter = 0
    start_at = Time.current
    action_tweets = Promote::ActionTweet.
      where(state: [:unrelated, :only_retweeted]).
      includes(:promote_user).
      order("promote_users.follower_count DESC ,promote_action_tweets.created_at DESC").
      limit(1000)
    action_tweets.each do |action_tweet|
      if action_tweet.like!(twitter_client: twitter_client)
        fail_counter = 0
      else
        fail_counter = fail_counter + 1
      end
      if fail_counter >= 5
        break
      end
    end
  end

  # 興味がありそうな人をフォローしていく
  def self.try_follows!
    twitter_client = TwitterBot.get_twitter_client(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    follow_counter = 0
    Promote::TwitterFriend.where(state: [:unrelated, :only_retweeted]).find_in_batches do |unfollow_friends|
      user_id_sum_score = Promote::ActionTweet.where(status_user_id: unfollow_friends.map(&:to_user_id)).where("created_at > ?", EFFECTIVE_PROMOTE_FILTER_SECOND.second.ago).group(:status_user_id).sum(:score)
      unfollow_friends.each do |unfollow_friend|
        next if follow_counter >= Promote::Friend::DAYLY_LIMIT_FOLLOW_COUNT || user_id_sum_score[unfollow_friend.to_user_id].blank?
        sum_score = user_id_sum_score[unfollow_friend.to_user_id]
        if (unfollow_friend.score + sum_score) >= Promote::Friend::FOLLOW_LIMIT_SCORE
          is_success = unfollow_friend.follow!(twitter_client: twitter_client)
          if is_success
            follow_counter = follow_counter + 1
          else
            break
          end
        end
      end
      break if follow_counter >= Promote::Friend::DAYLY_LIMIT_FOLLOW_COUNT
    end
  end

  # フォロワーを整理する
  def self.organize_follows!
    twitter_client = TwitterBot.get_twitter_client(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    twitter_bot = twitter_client.user
    follower_ids = twitter_client.follower_ids({count: 5000})
    twitter_friends = []
    Promote::TwitterFriend.where(state: [:unrelated, :only_follow], from_user_id: twitter_bot.id, to_user_id: follower_ids.to_a).find_each do |friend|
      friend.build_be_follower
      twitter_friends << friend
    end
    Promote::TwitterFriend.import!(twitter_friends, on_duplicate_key_update: [:state, :score])

    unfollow_count = 0
    unfollow_friends = Promote::TwitterFriend.where(state: :only_follow, from_user_id: twitter_bot.id, to_user_id: follower_ids.to_a).where("followed_at < ?", EFFECTIVE_PROMOTE_FILTER_SECOND.second.ago)
    unfollow_friends.each do |friend|
      is_success = friend.unfollow!(twitter_client: twitter_client)
      if is_success
        unfollow_count = unfollow_count + 1
      else
        break
      end
    end

    fail_follower_friends = Promote::TwitterFriend.where(state: [:only_follower, :both_follow], from_user_id: twitter_bot.id).where.not(to_user_id: follower_ids.to_a)
    fail_follower_friends.each do |friend|
      begin
        result = twitter_client.unfollow(friend.to_user_id.to_i)
      rescue Twitter::Error::TooManyRequests => e
        break
      end
      friend.update!(state: :unrelated, followed_at: nil, score: 0)
      unfollow_count = unfollow_count + 1
    end
  end

  def self.import_bot_followers!
    twitter_client = TwitterBot.get_twitter_client(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    twitter_bot = twitter_client.user
    Promote::TwitterFriend.update_all_followers!(twitter_client: twitter_client, user_id: twitter_bot.id)
  end
end
