# == Schema Information
#
# Table name: twitter_bots
#
#  id         :integer          not null, primary key
#  tweet      :string(255)      not null
#  tweet_id   :string(255)      not null
#  from_type  :string(255)
#  from_id    :integer
#  tweet_time :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_twitter_bots_on_from_type_and_from_id  (from_type,from_id)
#  index_twitter_bots_on_tweet_id               (tweet_id)
#

class TwitterBot < ApplicationRecord
  belongs_to :from, polymorphic: true, required: false

  def self.tweet!(text:, from: nil, options: {})
    twitter_client = self.get_twitter_client
    tweet_result = twitter_client.update(text, options)
    twitter_bot = TwitterBot.create!(tweet: tweet_result.text, tweet_id: tweet_result.id, tweet_time: tweet_result.created_at, from: from)
    return twitter_bot
  end

  def reject_tweet!
    twitter_client = TwitterBot.get_twitter_client
    result = twitter_client.destroy_status(self.tweet_id)
    destroy!
  end

  def self.get_twitter_client
    twitter_client =
      Twitter::REST::Client.new do |config|
        config.consumer_key = ENV.fetch('TWITTER_CONSUMER_KEY', '')
        config.consumer_secret = ENV.fetch('TWITTER_CONSUMER_SECRET', '')
        config.access_token = ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', '')
        config.access_token_secret = ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', '')
      end
    return twitter_client
  end
end
