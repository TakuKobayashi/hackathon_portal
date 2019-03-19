# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  shortener_url     :string(255)
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime
#  limit_number      :integer
#  address           :string(255)      not null
#  place             :string(255)      not null
#  lat               :float(24)
#  lon               :float(24)
#  cost              :integer          default(0), not null
#  max_prize         :integer          default(0), not null
#  currency_unit     :string(255)      default("円"), not null
#  owner_id          :string(255)
#  owner_nickname    :string(255)
#  owner_name        :string(255)
#  attend_number     :integer          default(0), not null
#  substitute_number :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  judge_state       :integer          default("before_judge"), not null
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

class TwitterEvent < Event
  def self.find_event(keywords:, page: 1)
    twitter_client = TwitterBot.get_twitter_client
    tweets = []
    retry_count = 0
    options = {count: 100}
    begin
      tweets = twitter_client.search(keywords, options)
    rescue Twitter::Error::TooManyRequests => e
      Rails.logger.warn "twitter retry since:#{e.rate_limit.reset_in.to_i}"
      retry_count = retry_count + 1
      sleep e.rate_limit.reset_in.to_i
      if retry_count < 5
        retry
      else
        return []
      end
    end
    return tweets
  end

  def self.import_events!
    page = 1
    update_columns = TwitterEvent.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    begin
      tweets = TwitterEvent.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], page: page)
      all_stringurls = tweets.map{|t| t.urls.map{|tu| tu.expanded_url.to_s } }.flatten
      stringurl_events = Event.where(url: all_stringurls).index_by(:url)

      transaction do
        tweets.each do |tweet|
          tweet.urls.each do |tweet_url|
            url = tweet_url.expanded_url
            next if stringurl_events[url.to_s].present?
            dom = RequestParser.request_and_parse_html(url: url.to_s, options: {:follow_redirect => true})
            twitter_event = TwitterEvent.new
            twitter_event.merge_event_attributes(attrs: {
              title: dom.title,
              url: url.to_s,
              address: nil,
              place: nil,
              lat: nil,
              lon: nil,
              attend_number: 0,
              max_prize: 0,
              currency_unit: "JPY",
              owner_id: tweet.user.id,
              owner_nickname: tweet.user.name,
              owner_name: tweet.user.screen_name,
              started_at: Time.now
            })
            twitter_event.save!
            twitter_event.import_hashtags!(hashtag_strings: twitter_event.hashtags)
          end
        end
      end
    end while tweets.present?
  end
end
