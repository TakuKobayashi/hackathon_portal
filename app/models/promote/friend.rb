# == Schema Information
#
# Table name: promote_friends
#
#  id           :bigint           not null, primary key
#  type         :string(255)
#  from_user_id :string(255)      not null
#  to_user_id   :string(255)      not null
#  state        :integer          default("unrelated"), not null
#  score        :float(24)        default(0.0), not null
#  followed_at  :datetime
#
# Indexes
#
#  index_promote_friends_on_followed_at                  (followed_at)
#  index_promote_friends_on_score                        (score)
#  index_promote_friends_on_to_user_id_and_from_user_id  (to_user_id,from_user_id)
#
class Promote::Friend < ApplicationRecord
  # TwitterAPIの仕様上1日にフォローできる人数の上限値
  DAYLY_LIMIT_FOLLOW_COUNT = 400

  # scoreがこの値以上になるのならfollowする
  FOLLOW_LIMIT_SCORE = 1

  FOLLOWER_ADD_SCORE = 0.6

  enum state: { unrelated: 0, only_follow: 1, only_follower: 10, both_follow: 11 }

  def follow!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    if self.only_follow? || self.both_follow?
      return false
    end
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    begin
      result = twitter_client.follow(self.to_user_id.to_i)
    rescue Twitter::Error::TooManyRequests => e
      return false
    end
    if self.unrelated?
      self.update!(state: :only_follow, followed_at: Time.current)
    elsif self.only_follower?
      self.update!(state: :both_follow, followed_at: Time.current)
    end
    return true
  end

  def unfollow!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    if self.unrelated? || self.only_follower?
      return false
    end
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    begin
      result = twitter_client.unfollow(self.to_user_id.to_i)
    rescue Twitter::Error::TooManyRequests => e
      return false
    end
    if self.only_follow?
      self.update!(state: :unrelated, followed_at: nil, score: self.score - FOLLOWER_ADD_SCORE)
    elsif self.both_follow?
      self.update!(state: :only_follower, followed_at: nil, score: self.score - FOLLOWER_ADD_SCORE)
    end
    return true
  end

  def be_follower!
    if self.only_follower? || self.both_follow?
      return false
    end
    if self.unrelated?
      self.update!(state: :only_follower, score: self.score + FOLLOWER_ADD_SCORE)
    elsif self.only_follow?
      self.update!(state: :both_follow, score: self.score + FOLLOWER_ADD_SCORE)
    end
  end
end
