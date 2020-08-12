module Promote
  def self.table_name_prefix
    'promote_'
  end

  def self.twitter_promote!
    self.like_major_user!
    self.try_follows!
  end

  # たぶんハッカソンについて呟いているツイート全て影響力が大きい人を中心にいいねする
  def self.like_major_user!
    action_tweets = Promote::ActionTweet.
      where(state: [:unrelated, :only_retweeted]).
      joins(:promote_user).
      order("promote_users.follower_count DESC ,promote_action_tweets.created_at DESC").
      limit(1000)
    action_tweets.each do |action_tweet|
      action_tweet.like!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    end
  end

  # 興味がありそうな人をフォローしていく
  def self.try_follows!
    follow_counter = 0
    Promote::TwitterFriend.where(state: [:unrelated, :only_retweeted]).find_in_batches do |unfollow_friends|
      user_id_sum_score = Promote::ActionTweet.where(status_user_id: unfollow_friends.map(&:to_user_id)).group(:status_user_id).sum(:score)
      unfollow_friends.each do |unfollow_friend|
        next if follow_counter >= Promote::Friend::DAYLY_LIMIT_FOLLOW_COUNT || user_id_sum_score[unfollow_friend.to_user_id].blank?
        sum_score = user_id_sum_score[unfollow_friend.to_user_id]
        if (unfollow_friend.score + sum_score) >= Promote::Friend::FOLLOW_LIMIT_SCORE
          is_success = unfollow_friend.follow!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
          if is_success
            follow_counter = follow_counter + 1
          end
        end
      end
      break if follow_counter >= Promote::Friend::DAYLY_LIMIT_FOLLOW_COUNT
    end
  end
end
