module Promote
  # 7日以上前にフォローしたけどフォロー返しされていなければフォローをするのをやめる
  EFFECTIVE_PROMOTE_FILTER_SECOND = 7 * 24 * 60 * 60

  def self.table_name_prefix
    'promote_'
  end

  def self.import_twitter_routine!
    self.import_bot_followers!
    self.import_followers_follower!
  end

  def self.twitter_promote_action!
    self.try_follows!
    self.organize_follows!
  end

  # とある内容について呟いているツイート全て影響力が大きい人を中心にいいねする
  def self.like_major_user!
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    fail_counter = 0
    start_at = Time.current
    action_tweets =
      Promote::ActionTweet.where(state: %i[unrelated only_retweeted]).includes(:promote_user).order(
        'promote_users.follower_count DESC ,promote_action_tweets.created_at DESC',
      )
    ja_action_tweets = action_tweets.where(lang: 'ja').limit(1000).to_a
    not_ja_action_tweets = action_tweets.where.not(lang: 'ja').limit(1000 - ja_action_tweets.size).to_a
    (ja_action_tweets + not_ja_action_tweets).each do |action_tweet|
      if action_tweet.like!(twitter_client: twitter_client)
        fail_counter = 0
        sleep 1
      else
        fail_counter = fail_counter + 1
      end
      break if fail_counter >= 2
    end
  end

  # 興味がありそうな人をフォローしていく
  def self.try_follows!
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    follow_counter = 0
    Promote::TwitterFriend.where(state: %i[unrelated only_follower]).find_in_batches do |unfollow_friends|
      user_id_sum_score =
        Promote::ActionTweet.where(status_user_id: unfollow_friends.map(&:to_user_id)).where(
          'created_at > ?',
          EFFECTIVE_PROMOTE_FILTER_SECOND.second.ago,
        ).group(:status_user_id).sum(:score)
      unfollow_friends.each do |unfollow_friend|
        if follow_counter >= Promote::Friend::DAYLY_LIMIT_FOLLOW_COUNT ||
             user_id_sum_score[unfollow_friend.to_user_id].blank?
          next
        end
        sum_score = user_id_sum_score[unfollow_friend.to_user_id]
        if (unfollow_friend.score + sum_score) >= Promote::Friend::FOLLOW_LIMIT_SCORE
          is_success = unfollow_friend.follow!(twitter_client: twitter_client)
          if is_success
            follow_counter = follow_counter + 1
            sleep 1
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
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    twitter_bot = twitter_client.user
    follower_ids = []
    begin
      follower_ids = twitter_client.follower_ids({ count: 5000 })
    rescue Twitter::Error::TooManyRequests => e
      return nil
    end
    twitter_friends = []
    Promote::TwitterFriend.where(
      state: %i[unrelated only_follow], from_user_id: twitter_bot.id, to_user_id: follower_ids.to_a,
    ).find_each do |friend|
      friend.build_be_follower
      twitter_friends << friend
    end
    Promote::TwitterFriend.import!(twitter_friends, on_duplicate_key_update: %i[state score])

    unfollow_count = 0
    unfollow_friends =
      Promote::TwitterFriend.where(state: :only_follow, from_user_id: twitter_bot.id, to_user_id: follower_ids.to_a)
        .where('followed_at < ?', EFFECTIVE_PROMOTE_FILTER_SECOND.second.ago)
    unfollow_friends.each do |friend|
      is_success = friend.unfollow!(twitter_client: twitter_client)
      if is_success
        unfollow_count = unfollow_count + 1
        sleep 1
      else
        return nil
      end
    end

    fail_follower_friends =
      Promote::TwitterFriend.where(state: %i[only_follower both_follow], from_user_id: twitter_bot.id).where.not(
        to_user_id: follower_ids.to_a,
      )
    fail_follower_friends.each do |friend|
      begin
        result = twitter_client.unfollow(friend.to_user_id.to_i)
      rescue Twitter::Error::TooManyRequests => e
        Rails.logger.warn(['TooManyRequests fail_follower unfollow Error:', e.message].join(' '))
        return nil
      rescue Twitter::Error::Forbidden => e
        Rails.logger.warn(['Forbidden fail_follower unfollow Error:', e.message].join(' '))
        return nil
      end
      friend.update!(state: :unrelated, followed_at: nil, score: 0)
      unfollow_count = unfollow_count + 1
      sleep 1
    end
  end

  def self.import_bot_followers!
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    twitter_bot = twitter_client.user
    Promote::TwitterFriend.update_all_followers!(twitter_client: twitter_client, user_id: twitter_bot.id)
  end

  def self.import_followers_follower!
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    twitter_bot = twitter_client.user
    friend_users =
      Promote::TwitterFriend.where(state: %i[only_follower both_follow], from_user_id: twitter_bot.id).includes(
        :to_promote_user,
      ).order('promote_friends.record_followers_follower_counter ASC')
    api_exec_count = 0
    rate_limit_res = Twitter::REST::Request.new(twitter_client, :get, '/1.1/application/rate_limit_status.json').perform
    friend_users.each do |friend_user|
      to_promote_user = friend_user.to_promote_user
      api_exec_count += (to_promote_user.follower_count / 5000) + 1
      friend_user.update!(record_followers_follower_counter: friend_user.record_followers_follower_counter + 1)
      Promote::TwitterFriend.update_all_followers!(twitter_client: twitter_client, user_id: friend_user.to_user_id)
      break if api_exec_count >= rate_limit_res[:resources][:followers][:"/followers/ids"][:remaining]
    end
  end
end
