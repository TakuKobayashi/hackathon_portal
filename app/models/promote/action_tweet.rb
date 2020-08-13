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

  # いいねをしたらフォローするかどうか判断するscoreの上昇値
  LIKE_ADD_SCORE = 0.25

  belongs_to :promote_user, class_name: 'Promote::TwitterUser', primary_key: "user_id", foreign_key: "status_user_id"

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

  def like!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    if self.only_liked? || self.liked_and_retweet?
      return false
    end
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    begin
      result = twitter_client.favorite(self.status_id)
    rescue Twitter::Error::TooManyRequests => e
      return false
    end

    if self.unrelated?
      self.update!(state: :only_liked, score: self.score + LIKE_ADD_SCORE)
    elsif self.only_retweeted?
      self.update!(state: :liked_and_retweet, score: self.score + LIKE_ADD_SCORE)
    end
    return true
  end
end
