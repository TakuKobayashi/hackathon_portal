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

  def self.tweet!(text:, from: nil, access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''), options: {})
    twitter_client = self.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    tweet_result = twitter_client.update(text, options)
    twitter_bot =
      TwitterBot.create!(
        tweet: tweet_result.text, tweet_id: tweet_result.id, tweet_time: tweet_result.created_at, from: from,
      )
    return twitter_bot
  end

  def reject_tweet!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    result = twitter_client.destroy_status(self.tweet_id)
    destroy!
  end

  def self.promote!(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    twitter_client = self.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    follower_ids = twitter_client.follower_ids({count: 5000})
    follower_ids.each do |follower_id|
      csrf_token = SecureRandom.hex
      json = RequestParser.request_and_parse_json(
        url: "https://api.twitter.com/2/timeline/liked_by.json",
        params: {
          include_profile_interstitial_type: 1,
          include_blocking: 1,
          include_blocked_by: 1,
          include_followed_by: 1,
          include_want_retweets: 1,
          include_mute_edge: 1,
          include_can_dm: 1,
          include_can_media_tag: 1,
          skip_status: 1,
          cards_platform: "Web-12",
          include_cards: 1,
          include_ext_alt_text: true,
          include_quote_count: true,
          include_reply_count: 1,
          tweet_mode: "extended",
          include_entities: true,
          include_user_entities: true,
          include_ext_media_color: true,
          include_ext_media_availability: true,
          send_error_codes: true,
          simple_quoted_tweet: true,
          tweet_id: follower_id,
          count: 80,
          ext: 'mediaStats%2ChighlightedLabel',
        },
        header: {
          # auth_token と Bearer token は調べて入れる必要がある
          "authorization" => ["Bearer", twitter_client.token].join(" "),
          "x-csrf-token" => csrf_token,
          'cookie' => ['auth_token=' + csrf_token + ';', 'ct0=' + csrf_token + ';'].join(" ")
        }
      )
    end
  end

  def self.get_twitter_client(
    access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
    access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', '')
  )
    twitter_client =
      Twitter::REST::Client.new do |config|
        config.consumer_key = ENV.fetch('TWITTER_CONSUMER_KEY', '')
        config.consumer_secret = ENV.fetch('TWITTER_CONSUMER_SECRET', '')
        config.access_token = access_token
        config.access_token_secret = access_token_secret
      end
    return twitter_client
  end
end
