# == Schema Information
#
# Table name: promote_users
#
#  id             :bigint           not null, primary key
#  user_id        :string(255)      not null
#  type           :string(255)
#  screen_name    :string(255)      not null
#  state          :integer          default("unrelated"), not null
#  follower_count :integer          default(0), not null
#  follow_count   :integer          default(0), not null
#
# Indexes
#
#  index_promote_users_on_user_id_and_type  (user_id,type) UNIQUE
#
class Promote::TwitterUser < Promote::User
  has_many :follow_friends, class_name: 'Promote::TwitterFriend', primary_key: 'user_id', foreign_key: 'to_user_id'
  has_many :action_tweets, class_name: 'Promote::ActionTweet', primary_key: 'user_id', foreign_key: 'status_user_id'

  # データ量を絞るためにフォロワー100人以下は記録しない
  LIMIT_FOLLOWER_COUNT = 100

  def self.import_from_tweets!(tweets: [])
    self.import_from_users!(twitter_users: tweets.map(&:user).uniq)
  end

  def self.import_from_users!(twitter_users: [])
    user_id_promote_tweet_users =
      Promote::TwitterUser.where(user_id: twitter_users.map { |u| u.id.to_s }).index_by(&:user_id)
    promote_twitter_users = []
    twitter_users.each do |twitter_user|
      next if twitter_user.status.created_at <= Promote::EFFECTIVE_PROMOTE_FILTER_SECOND.second.ago
      next if twitter_user.followers_count <= Promote::TwitterUser::LIMIT_FOLLOWER_COUNT
      promote_twitter_user = user_id_promote_tweet_users[twitter_user.id.to_s]
      if promote_twitter_user.blank?
        current_time = Time.current
        promote_twitter_user =
          Promote::TwitterUser.new(
            id:
              (
                # 現在時刻(マイクロ秒)をidとして記録
                current_time.to_i * 1000000
              ) + current_time.usec,
            user_id: twitter_user.id,
            screen_name: twitter_user.screen_name,
            state: :unrelated,
          )
      end
      promote_twitter_user.follower_count = twitter_user.followers_count
      promote_twitter_user.follow_count = twitter_user.friends_count
      promote_twitter_users << promote_twitter_user
    end
    Promote::TwitterUser.import!(promote_twitter_users, on_duplicate_key_update: %i[follower_count follow_count])
  end
end
