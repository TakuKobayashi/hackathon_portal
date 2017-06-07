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

  def self.tweet!(text:, from: nil)
    apiconfig = YAML.load(File.open(Rails.root.to_s + "/config/apiconfig.yml"))
    twitter_client = Twitter::REST::Client.new do |config|
      config.consumer_key        = apiconfig["twitter"]["consumer_key"]
      config.consumer_secret     = apiconfig["twitter"]["consumer_secret"]
      config.access_token        = apiconfig["twitter"]["bot"]["access_token_key"]
      config.access_token_secret = apiconfig["twitter"]["bot"]["access_token_secret"]
    end
    tweet_result = twitter_client.update(text)
    twitter_bot = TwitterBot.create!(tweet: tweet_result.text, tweet_id: tweet_result.id, tweet_time: tweet_result.created_at, from: from)
    return twitter_bot
  end
end
