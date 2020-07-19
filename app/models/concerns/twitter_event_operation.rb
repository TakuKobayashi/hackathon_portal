module TwitterEventOperation
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
        tweets_response = self.find_tweets(keywords: keywords, options: { max_id: max_tweet_id })
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
          twitter_event = Event.new
          twitter_event.merge_event_attributes(
            attrs:
              extra_info.to_h.merge(
                {
                  informed_from: :twitter,
                  title: extra_info.title.to_s,
                  description: extra_info.description.to_s,
                  url: url.to_s,
                  address: extra_info.address.to_s,
                  place: extra_info.place.to_s,
                  event_id: tweet.id,
                  attend_number: 0,
                  max_prize: 0,
                  currency_unit: 'JPY',
                  owner_id: tweet.user.id,
                  owner_nickname: tweet.user.name,
                  owner_name: tweet.user.screen_name,
                  started_at: extra_info.started_at
                }
              )
          )
          if twitter_event.hackathon_event? || twitter_event.development_camp?
            twitter_event.save!
            twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
          end
        end
      end
      max_tweet_id = tweets.last.try(:id)
    end while tweets.size >= PAGE_PER
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
