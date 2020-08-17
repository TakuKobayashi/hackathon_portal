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
#  lang                    :string(255)      not null
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
  # APIからのいいねはエラーになることが多いので先にscoreを加算してしまう
  LIKE_ADD_SCORE = 0.25

  belongs_to :promote_user, class_name: 'Promote::TwitterUser', primary_key: 'user_id', foreign_key: 'status_user_id'

  def tweet_url
    return "https://twitter.com/#{self.status_user_screen_name}/status/#{self.status_id}"
  end

  def self.import_tweets!(me_user:, tweets: [])
    status_id_promote_tweets = Promote::ActionTweet.where(status_id: tweets.map { |t| t.id.to_s }).index_by(&:status_id)
    promote_action_tweets = []
    tweets.each do |tweet|
      next if status_id_promote_tweets[tweet.id.to_s].present?
      promote_action_tweets <<
        Promote::ActionTweet.new(
          user_id: me_user.id,
          status_user_id: tweet.user.id,
          status_user_screen_name: tweet.user.screen_name,
          status_id: tweet.id,
          state: :unrelated,
          score: LIKE_ADD_SCORE,
          lang: tweet.lang,
          created_at: tweet.created_at,
        )
    end
    Promote::ActionTweet.import!(promote_action_tweets)
  end

  def like!(twitter_client:)
    return false if self.only_liked? || self.liked_and_retweet?
    begin
      liked_tweets = twitter_client.favorite(self.status_id.to_i)
      # blockされているユーザーをlikeすることはできない
    rescue Twitter::Error::Unauthorized => e
      Rails.logger.warn(['Unauthorized like! Error:', e.message, self.tweet_url].join(' '))
      return true
    rescue Twitter::Error::Forbidden => e
      Rails.logger.warn(['Forbidden like! Error:', e.message, self.tweet_url].join(' '))
      # 鍵垢をいいねすることはできない
      if e.message.include?('protected users')
        return true
      else
        return false 
      end
    rescue Twitter::Error::TooManyRequests => e
      Rails.logger.warn(['TooManyRequest like! Error:', e.rate_limit.reset_in, 's', self.tweet_url].join(' '))
      return false
    end

    success = false
    if self.unrelated?
      success = self.update(state: :only_liked)
    elsif self.only_retweeted?
      success = self.update(state: :liked_and_retweet)
    end
    return success
  end
end
