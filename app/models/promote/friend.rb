# == Schema Information
#
# Table name: promote_friends
#
#  id                                :bigint           not null, primary key
#  type                              :string(255)
#  from_user_id                      :string(255)      not null
#  to_user_id                        :string(255)      not null
#  state                             :integer          default("unrelated"), not null
#  score                             :float(24)        default(0.0), not null
#  followed_at                       :datetime
#  record_followers_follower_counter :integer          default(0), not null
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

  # Botのフォロワーだった時の上昇するscore値
  FOLLOWER_ADD_SCORE = 0.9

  # フォロワーのフォロワーだった時の上昇するscore値
  FOLLOWERS_FOLLOWER_ADD_SCORE = 0.5

  belongs_to :to_promote_user, class_name: 'Promote::TwitterUser', primary_key: 'user_id', foreign_key: 'to_user_id'

  enum state: { unrelated: 0, only_follow: 1, only_follower: 10, both_follow: 11 }

  scope :followers, -> { where(state: %i[only_follower both_follow]) }

  def follow!(twitter_client:)
    return false if self.only_follow? || self.both_follow?
    begin
      follow_users = twitter_client.follow!(self.to_user_id.to_i)
      return false unless follow_users.any? { |t| t.id.to_i == self.to_user_id.to_i }
    rescue Twitter::Error::TooManyRequests => e
      Rails.logger.warn([['TooManyRequest follow Error:', e.rate_limit.reset_in.to_s, 's'].join, e.message].join('\n'))
      return false
    end
    if self.unrelated?
      self.update!(state: :only_follow, followed_at: Time.current)
    elsif self.only_follower?
      self.update!(state: :both_follow, followed_at: Time.current)
    end
    return true
  end

  def unfollow!(twitter_client:)
    return false if self.unrelated? || self.only_follower?
    begin
      unfollow_users = twitter_client.unfollow!(self.to_user_id.to_i)
      return false unless unfollow_users.any? { |t| t.id.to_i == self.to_user_id.to_i }
    rescue Twitter::Error::TooManyRequests => e
      Rails.logger.warn(
        [['TooManyRequest unfollow Error:', e.rate_limit.reset_in.to_s, 's'].join, e.message].join('\n'),
      )
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
    success = self.build_be_follower
    self.save! if success
    return success
  end

  def build_be_follower
    return false if self.only_follower? || self.both_follow?
    if self.unrelated?
      self.state = :only_follower
    elsif self.only_follow?
      self.state = :both_follow
    end
    self.score = self.score + FOLLOWER_ADD_SCORE
    return true
  end
end
