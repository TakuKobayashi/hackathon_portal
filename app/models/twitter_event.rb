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
#  index_events_on_event_id_and_type        (event_id,type)
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#  index_events_on_url                      (url)
#

class TwitterEvent < Event
  TWITTER_SEARCH_HACKATHON_KEYWORDS = %w[hackathon ハッカソン アイディアソン アイデアソン ゲームジャム ideathon 開発合宿]

  def self.import_events!
    update_columns = TwitterEvent.column_names - %w[id type shortener_url event_id created_at]
    twitter_client = TwitterBot.get_twitter_client
    tweet_counter = 0
    retry_count = 0
    request_options = { count: 100, result_type: 'recent', exclude: 'retweets' }
    tweets = twitter_client.search((TWITTER_SEARCH_HACKATHON_KEYWORDS).join(' OR '), request_options)
    begin
      tweets.each(tweet_counter) do |tweet|
        tweet_counter = tweet_counter + 1
        urls = tweet.urls.map(&:expanded_url)
        next if urls.blank?
        next if TwitterEvent.exists?(event_id: tweet.id)
        exists_events = Event.where(url: urls.map(&:to_s)).index_by(&:url)
        urls.each do |url|
          next if exists_events[url.to_s].present?
          extra_info = self.scrape_extra_info(url.to_s)
          next if extra_info.title.blank?

          #TODO 要ハッカソンイベントかどうかのフィルタリング
          twitter_event = TwitterEvent.new
          twitter_event.merge_event_attributes(
            attrs:
              extra_info.to_h.merge(
                {
                  url: url.to_s,
                  event_id: tweet.id,
                  attend_number: 0,
                  max_prize: 0,
                  currency_unit: 'JPY',
                  owner_id: tweet.user.id,
                  owner_nickname: tweet.user.name,
                  owner_name: tweet.user.screen_name,
                  started_at: Time.now
                }
              )
          )
          twitter_event.save!
          twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
        end
      end
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
  end

  private

  def self.scrape_extra_info(url)
    #TODO 開催日時のスクレイピング
    dom = RequestParser.request_and_parse_html(url: url.to_s, options: { follow_redirect: true })
    result = OpenStruct.new({ title: dom.try(:title).to_s.truncate(140) })
    dom.css('meta').each do |meta_dom|
      dom_attrs = OpenStruct.new(meta_dom.to_h)
      if result.description.blank?
        if dom_attrs.name == 'description'
          result.description = dom_attrs.content
        elsif dom_attrs.property == 'og:description'
          result.description = dom_attrs.content
        end
      end
    end
    #      sanitized_body_html = Sanitizer.basic_sanitize(dom.css("body").to_html)
    #      scaned_urls = Sanitizer.scan_urls(sanitized_body_html)

    sanitized_body_text = Sanitizer.basic_sanitize(dom.css('body').text)
    address_canididates = Sanitizer.scan_japan_address(sanitized_body_text)

    result.address = Sanitizer.match_address_text(address_canididates.first.to_s).to_s
    result.place = result.address
    return result
  end
end
