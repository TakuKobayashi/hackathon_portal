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
  FOLLOWERS_FOLLOWER_ADD_SCORE = 0.25

  enum state: { unrelated: 0, only_follow: 1, only_follower: 10, both_follow: 11 }

  scope :followers, -> { where(state: %i[only_follower both_follow]) }

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
