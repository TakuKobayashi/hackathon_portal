# == Schema Information
#
# Table name: promote_action_tweets
#
#  id                      :bigint           not null, primary key
#  user_id                 :string(255)      not null
#  status_user_id          :string(255)      not null
#  status_user_screen_name :string(255)      not null
#  status_id               :string(255)      not null
#  state                   :integer          default("unrelated"), not null
#  score                   :float(24)        default(0.0), not null
#  created_at              :datetime         not null
#
# Indexes
#
#  index_promote_action_tweets_on_created_at      (created_at)
#  index_promote_action_tweets_on_status_id       (status_id)
#  index_promote_action_tweets_on_status_user_id  (status_user_id)
#  index_promote_action_tweets_on_user_id         (user_id)
#
class Promote::ActionTweet < ApplicationRecord
  enum state: { unrelated: 0, only_liked: 1, only_retweeted: 10, liked_and_retweet: 11 }

  def self.import_tweets!(me_user:, tweets: [])
    status_id_promote_tweets = Promote::ActionTweet.where(status_id: tweets.map{|t| t.id.to_s}).index_by(&:status_id)
    promote_action_tweets = []
    tweets.each do |tweet|
      next if status_id_promote_tweets[tweet.id.to_s].present?
      promote_action_tweets << Promote::ActionTweet.new(
        user_id: me_user.id,
        status_user_id: tweet.user.id,
        status_user_screen_name: tweet.user.screen_name,
        status_id: tweet.id,
        state: :unrelated,
        score: 0,
        created_at: tweet.created_at,
      )
    end
    Promote::ActionTweet.import!(promote_action_tweets)
  end
end
