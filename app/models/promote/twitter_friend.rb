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
class Promote::TwitterFriend < Promote::Friend
  belongs_to :promote_user, class_name: 'Promote::TwitterUser', primary_key: "user_id", foreign_key: "to_user_id"

  def self.import_from_tweets!(me_user:, tweets: [])
    self.import_from_users!(me_user: me_user, twitter_users: tweets.map(&:user).uniq)
  end

  def self.import_from_users!(me_user:, twitter_users: [])
    to_user_id_twitter_friends = Promote::TwitterFriend.where(from_user_id: me_user.id, to_user_id: twitter_users.map{|tu| tu.id.to_s }).index_by(&:to_user_id)
    promote_twitter_friends = []
    twitter_users.each do |twitter_user|
      next if to_user_id_twitter_friends[twitter_user.id.to_s].present?
      promote_twitter_friends << Promote::TwitterFriend.new(
        from_user_id: me_user.id,
        to_user_id: twitter_user.id,
        state: :unrelated,
        score: 0,
      )
    end
    Promote::TwitterFriend.import!(promote_twitter_friends)
  end
end
