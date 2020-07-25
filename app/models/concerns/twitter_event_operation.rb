module TwitterEventOperation
  PAGE_PER = 100

  def self.find_tweets(keywords:, options: {})
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', '')
      )
    request_options = { count: PAGE_PER, result_type: 'recent', exclude: 'retweets' }.merge(options)
    return twitter_client.search(keywords.join(' OR '), request_options)
  end

  def self.import_events_from_keywords!(keywords:)
    last_twitter_event = Event.twitter.last
    update_columns = Event.column_names - %w[id type shortener_url event_id created_at]
    tweet_counter = 0
    retry_count = 0
    max_tweet_id = nil
    tweets = []
    begin
      tweets_response = []
      begin
        tweets_response = self.find_tweets(keywords: keywords, options: {
          max_id: max_tweet_id, since_id: last_twitter_event.try(:event_id),
        })
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
      tweets.sort_by!{|tweet| -tweet.id }
      url_twitter_events = self.find_by_all_relative_events_from_tweets(tweets: tweets).index_by(&:url)

      Parallel.each(tweets, in_threads: tweets.size) do |tweet|
        tweet_counter = tweet_counter + 1
        twitter_events = self.save_twitter_events_form_tweet!(tweet: tweet, current_url_twitter_events: url_twitter_events)
        twitter_events.each do |twitter_event|
          url_twitter_events[twitter_event.url] = twitter_event
        end
        if tweet.quoted_status?
          quoted_twitter_events = self.save_twitter_events_form_tweet!(tweet: tweet.quoted_status, current_url_twitter_events: url_twitter_events)
          quoted_twitter_events.each do |twitter_event|
            url_twitter_events[twitter_event.url] = twitter_event
          end
        end
      end

      max_tweet_id = tweets.last.try(:id)
    end while tweets.size > 0
  end

  private
  def self.save_twitter_events_form_tweet!(tweet:, current_url_twitter_events:)
    saved_twitter_events = []
    urls = tweet.urls.map(&:expanded_url)
    return saved_twitter_events if urls.blank?
    urls.each do |url|
      next if current_url_twitter_events[url.to_s].present?
      if url.host.include?("twitter.com")
        next
      end
      twitter_event = Event.new(url: url.to_s, informed_from: :twitter, state: :active)
      twitter_event.build_from_website
      if twitter_event.title.blank? || twitter_event.place.blank? || twitter_event.started_at.blank?
        next
      end
      twitter_event.merge_event_attributes(
        attrs: {
          event_id: tweet.id,
          attend_number: 0,
          max_prize: 0,
          currency_unit: 'JPY',
          owner_id: tweet.user.id,
          owner_nickname: tweet.user.name,
          owner_name: tweet.user.screen_name
        }
      )
      if twitter_event.hackathon_event? || twitter_event.development_camp?
        twitter_event.save!
        twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
        saved_twitter_events << twitter_event
      end
    end

    return saved_twitter_events
  end

  def self.find_by_all_relative_events_from_tweets(tweets: [])
    all_twitter_ids = tweets.map do |tweet|
      [tweet.id.to_s, tweet.quoted_status.id.to_s]
    end.flatten.select(&:present?)
    twitter_events = Event.twitter.where(event_id: all_twitter_ids)

    all_urls = tweets.map do |tweet|
      urls = tweet.urls.map{|u| u.expanded_url.to_s }
      if tweet.quoted_status?
        urls += tweet.quoted_status.urls.map{|u| u.expanded_url.to_s }
      end
      urls
    end.flatten.uniq

    twitter_events += Event.where(url: all_urls)
    return twitter_events.uniq
  end
end
