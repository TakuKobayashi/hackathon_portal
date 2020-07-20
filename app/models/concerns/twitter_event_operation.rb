module TwitterEventOperation
  def self.find_tweets(keywords:, options: {})
    twitter_client = TwitterBot.get_twitter_client(access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''))
    request_options = { count: PAGE_PER, result_type: 'recent', exclude: 'retweets' }.merge(options)
    return twitter_client.search(keywords.join(' OR '), request_options)
  end

  def self.import_events_from_keywords!(event_clazz:, keywords:)
    last_twitter_event = Event.twitter.last
    update_columns = event_clazz.column_names - %w[id type shortener_url event_id created_at]
    tweet_counter = 0
    retry_count = 0
    tweets_response = []
    begin
      max_tweet_id = nil
      begin
        tweets_response = self.find_tweets(keywords: keywords, options: { max_id: max_tweet_id, since_id: last_twitter_event.try(:event_id) })
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
      url_twitter_events = Event.twitter.where(event_id: tweets.map(&id)).index_by(&:url)
      tweets.each do |tweet|
        tweet_counter = tweet_counter + 1
        urls = tweet.urls.map(&:expanded_url)
        next if urls.blank?
        urls.each do |url|
          next if url_twitter_events[url.to_s].present?
          extra_info = self.scrape_extra_info(url.to_s)
          next if extra_info.title.blank?

          #TODO 要ハッカソンイベントかどうかのフィルタリング
          twitter_event = Event.new(
            url: url.to_s,
            informed_from: :twitter,
          )
          twitter_event.build_from_website
          twitter_event.merge_event_attributes(
            attrs:
              extra_info.to_h.merge(
                {
                  event_id: tweet.id,
                  attend_number: 0,
                  max_prize: 0,
                  currency_unit: 'JPY',
                  owner_id: tweet.user.id,
                  owner_nickname: tweet.user.name,
                  owner_name: tweet.user.screen_name
                }
              )
          )
          if twitter_event.hackathon_event? || twitter_event.development_camp?
            twitter_event.save!
            twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
            url_twitter_events[url] = twitter_event
          end
        end
      end
      max_tweet_id = tweets.last.try(:id)
    end while tweets.size >= PAGE_PER
  end
end
