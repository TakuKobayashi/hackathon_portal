module TwitterEventOperation
  PEATIX_ROOT_URL = 'http://peatix.com'
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + '/search/events'

  PAGE_PER = 100

  def self.find_tweets(keywords:, options: {})
    twitter_client = TwitterBot.get_twitter_client
    request_options = { count: PAGE_PER, result_type: 'recent', exclude: 'retweets' }.merge(options)
    return twitter_client.search(keywords.join(' OR '), request_options)
  end

  def self.import_events_from_keywords!(event_clazz:, keywords:)
    update_columns = event_clazz.column_names - %w[id type shortener_url event_id created_at]
    tweet_counter = 0
    retry_count = 0
    tweets_response = []
    begin
      max_tweet_id = nil
      begin
        tweets_response = self.find_tweets(keywords: keywords, options: {max_id: max_tweet_id})
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
      tweets = tweets_response.take(PAGE_PER)
      tweets.each do |tweet|
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
      max_tweet_id = tweets.last.try(:id)
    end while tweets.size >= PAGE_PER
  end
end