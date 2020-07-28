module TwitterEventOperation
  PAGE_PER = 100

  def self.find_tweets(keywords:, options: {})
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    request_options = { count: PAGE_PER, result_type: 'recent', exclude: 'retweets' }.merge(options)
    return twitter_client.search(keywords.join(' OR '), request_options)
  end

  def self.import_events_from_keywords!(keywords:, options: {})
    execute_option_structs = OpenStruct.new(options)
    if options.has_key?(:default_since_tweet_id)
      since_tweet_id = execute_option_structs.default_since_tweet_id
    else
      since_tweet_id = Event.twitter.last.try(:event_id)
    end
    max_tweet_id = execute_option_structs.default_max_tweet_id
    limit_execute_second = execute_option_structs.limit_execute_second || 3600

    tweet_counter = 0
    retry_count = 0
    tweets = []
    start_time = Time.current
    begin
      tweets_response = []
      begin
        tweets_response =
          self.find_tweets(keywords: keywords, options: { max_id: max_tweet_id, since_id: since_tweet_id })
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
      tweets.sort_by! { |tweet| -tweet.id }
      url_twitter_events = self.find_by_all_relative_events_from_tweets(tweets: tweets).index_by(&:url)

      # 降順に並んでいるのでreverse_eachをして古い順にデータを作っていくようにする
      tweets.reverse_each do |tweet|
        tweet_counter = tweet_counter + 1
        twitter_events =
          self.save_twitter_events_form_tweet!(tweet: tweet, current_url_twitter_events: url_twitter_events)
        if tweet.quoted_status?
          quoted_twitter_events =
            self.save_twitter_events_form_tweet!(
              tweet: tweet.quoted_status, current_url_twitter_events: url_twitter_events,
            )
        end
      end

      max_tweet_id = tweets.last.try(:id)
    end while tweets.size >= PAGE_PER && (Time.current - start_time).second < limit_execute_second
  end

  private

  def self.save_twitter_events_form_tweet!(tweet:, current_url_twitter_events:)
    saved_twitter_events = []
    urls = tweet.urls.map(&:expanded_url)
    return saved_twitter_events if urls.blank?
    urls.each do |url|
      Rails.logger.info(url)
      next if current_url_twitter_events[url.to_s].present?
      next if url.host.include?('twitter.com') || url.host.include?('youtu.be') || url.host.include?('youtube.com')
      twitter_event = Event.new(url: url.to_s, informed_from: :twitter, state: :active)
      twitter_event.build_from_website
      next if twitter_event.title.blank? || twitter_event.place.blank? || twitter_event.started_at.blank?
      twitter_event.merge_event_attributes(
        attrs: {
          event_id: tweet.id,
          attend_number: 0,
          max_prize: 0,
          currency_unit: 'JPY',
          owner_id: tweet.user.id,
          owner_nickname: tweet.user.name,
          owner_name: tweet.user.screen_name,
        },
      )
      if twitter_event.hackathon_event? || twitter_event.development_camp?
        begin
          twitter_event.save!
          twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
          current_url_twitter_events[twitter_event.url] = twitter_event
        rescue Exception => error
          Rails.logger.warn("Data save error #{twitter_event.attributes}")
        end
      end
    end

    return saved_twitter_events
  end

  def self.find_by_all_relative_events_from_tweets(tweets: [])
    all_twitter_ids = tweets.map { |tweet| [tweet.id.to_s, tweet.quoted_status.id.to_s] }.flatten.select(&:present?)
    twitter_events = Event.twitter.where(event_id: all_twitter_ids)

    all_urls =
      tweets.map do |tweet|
        urls = tweet.urls.map { |u| u.expanded_url.to_s }
        urls += tweet.quoted_status.urls.map { |u| u.expanded_url.to_s } if tweet.quoted_status?
        urls
      end.flatten.uniq

    twitter_events += Event.where(url: all_urls)
    return twitter_events.uniq
  end
end
