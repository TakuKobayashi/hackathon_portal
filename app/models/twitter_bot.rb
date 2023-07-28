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

  def self.tweet!(twitter_oauth_token:, text:, from: nil, options: {})
    tweet_result_hash =
      RequestParser.request_and_parse_json(
        url: 'https://api.twitter.com/2/tweets',
        method: :post,
        header: {
          'Content-Type': 'application/json; charset=utf-8',
          Authorization: ['Bearer', twitter_oauth_token.access_token].join(' '),
        },
        body: { text: text }.to_json,
      )
    tweet_result = OpenStruct.new(tweet_result_hash['data'])
    #    twitter_client = self.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    #    tweet_result = twitter_client.update(text, options)
    twitter_bot =
      TwitterBot.create!(tweet: tweet_result.text, tweet_id: tweet_result.id, tweet_time: Time.current, from: from)
    return twitter_bot
  end

  def reject_tweet!(
    access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
    access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', '')
  )
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    begin
      result = twitter_client.destroy_status(self.tweet_id)
    rescue Twitter::Error::NotFound => e
      Rails.logger.warn((["error: #{e.message}"] + e.backtrace).join("\n"))
    end
    self.destroy!
  end

  def self.load_twitter_oauth_token
    firestore =
      Google::Cloud::Firestore.new(
        project_id: ENV.fetch('FIRESTORE_PROJECT_ID', ''),
        credentials: Rails.root.join('firebase_config.json'),
      )
    record_token_doc = firestore.col('twitter_oauth2_token').doc('HackathonPortal')
    record_token = record_token_doc.get()
    record_token_data = OpenStruct.new(record_token.data())
    if Time.current > record_token.updated_at + record_token_data.expires_in
      refreshed_token_hash =
        RequestParser.request_and_parse_json(
          url: 'https://api.twitter.com/2/oauth2/token',
          method: :post,
          header: {
            'Content-Type' => 'application/x-www-form-urlencoded',
            :Authorization => [
              'Basic',
              Base64.strict_encode64(
                [ENV.fetch('TWITTER_OAUTH2_CLIENT_ID', ''), ENV.fetch('TWITTER_OAUTH2_CLIENT_SECRET', '')].join(':'),
              ),
            ].join(' '),
          },
          body:
            URI.encode_www_form(
              {
                refresh_token: record_token_data.refresh_token,
                grant_type: 'refresh_token',
                client_id: ENV.fetch('TWITTER_OAUTH2_CLIENT_ID', ''),
              },
            ),
        )
      record_token_doc.set(refreshed_token_hash)
      record_token_data = OpenStruct.new(refreshed_token_hash)
    end

    return record_token_data
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
