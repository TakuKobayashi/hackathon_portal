module TwitterEventOperation
  PAGE_PER = 100
  TWITTER_HOST = 'twitter.com'
  EXCLUDE_CHECK_EVENT_HOSTS = %w[youtu.be youtube.com github.com]

  def self.find_tweets(
    keywords:,
    access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
    access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
    options: {}
  )
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    request_options = { count: PAGE_PER, result_type: 'recent', exclude: 'retweets' }.merge(options)
    return twitter_client.search(keywords.join(' OR '), request_options)
  end

  def self.import_events_from_keywords!(
    keywords:,
    access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
    access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
    options: {}
  )
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

    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    me_twitter = twitter_client.user
    begin
      break if max_tweet_id.present? && since_tweet_id.present? && max_tweet_id.to_i < since_tweet_id.to_i
      tweets_response = []
      begin
        tweets_response =
          self.find_tweets(
            keywords: keywords,
            access_token: access_token,
            access_token_secret: access_token_secret,
            options: { max_id: max_tweet_id, since_id: since_tweet_id },
          )
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
      take_tweets = tweets_response.take(PAGE_PER)
      take_tweets.sort_by! { |tweet| -tweet.id }
      twitter_url_tweets = self.expanded_tweets_from_twitter_url(tweets: take_tweets, twitter_client: twitter_client)
      tweets = take_tweets + twitter_url_tweets
      tweets.uniq!
      tweets.sort_by! { |tweet| -tweet.id }
      url_twitter_events = self.find_by_all_relative_events_from_tweets(tweets: tweets).index_by(&:url)

      saved_twitter_events = []
      # 降順に並んでいるのでreverse_eachをして古い順にデータを作っていくようにする
      tweets.reverse_each do |tweet|
        next if me_twitter.id == tweet.user.id
        tweet_counter = tweet_counter + 1
        saved_twitter_events +=
          self.save_twitter_events_form_tweet!(tweet: tweet, current_url_twitter_events: url_twitter_events)
        if tweet.quoted_status?
          saved_twitter_events +=
            self.save_twitter_events_form_tweet!(
              tweet: tweet.quoted_status, current_url_twitter_events: url_twitter_events,
            )
        end
      end

      saved_twitter_events.uniq.each do |saved_twitter_event|
        saved_twitter_event.build_location_data
        saved_twitter_event.save!
      end

      self.import_relation_promote_tweets!(me_user: me_twitter, tweets: tweets)
      max_tweet_id = take_tweets.last.try(:id)
    end while (tweets.size >= PAGE_PER && (Time.current - start_time).second < limit_execute_second) ||
      (max_tweet_id.present? && since_tweet_id.present? && max_tweet_id.to_i < since_tweet_id.to_i)
  end

  def self.import_relation_promote_tweets!(me_user:, tweets: [])
    all_tweets =
      tweets.map do |tweet|
        tweet_arr = []

        if tweet.user.id != me_user.id
          tweet_arr << tweet
          tweet_arr << tweet.quoted_status if tweet.quoted_status?
        end
        tweet_arr
      end.flatten.uniq
    Promote::ActionTweet.import_tweets!(me_user: me_user, tweets: all_tweets)
    Promote::TwitterUser.import_from_tweets!(tweets: all_tweets)
    Promote::TwitterFriend.import_from_tweets!(me_user: me_user, tweets: all_tweets)
    return all_tweets
  end

  private

  def self.save_twitter_events_form_tweet!(tweet:, current_url_twitter_events:)
    saved_twitter_events = []
    urls = tweet.urls.map(&:expanded_url)
    return saved_twitter_events if urls.blank?
    urls.each do |url|
      Rails.logger.info(url)
      next if current_url_twitter_events[url.to_s].present?
      # TwitterのURLは除外する
      next if url.host.include?(TWITTER_HOST)
      # Facebookのvideoとかもイベントページではないと思う
      next if url.path.include?('video')
      # Youtube, Github他、絶対にイベント情報じゃないHOSTはあらかじめ弾く
      next if EXCLUDE_CHECK_EVENT_HOSTS.any? { |event_host| url.host.include?(event_host) }
      twitter_event = Event.new(url: url.to_s, informed_from: :twitter, state: :active)
      build_result = twitter_event.build_from_website
      next if build_result.blank?
      next if twitter_event.title.blank? || twitter_event.place.blank? || twitter_event.started_at.blank?
      # 短縮URLなどで上書きれてしまっている可能性があるので再度チェック
      next if current_url_twitter_events[twitter_event.url.to_s].present?
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
      if twitter_event.type.present?
        begin
          twitter_event.save!
          twitter_event.import_hashtags!(hashtag_strings: tweet.hashtags.map(&:text))
          current_url_twitter_events[twitter_event.url.to_s] = twitter_event
          saved_twitter_events << twitter_event
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

  def self.expanded_tweets_from_twitter_url(tweets: [], twitter_client:)
    all_twitter_urls =
      tweets.map do |tweet|
        urls = tweet.urls.map { |u| u.expanded_url }
        urls += tweet.quoted_status.urls.map { |u| u.expanded_url } if tweet.quoted_status?
        urls
      end.flatten.uniq.select { |url| url.host == TWITTER_HOST }
    tweet_ids =
      all_twitter_urls.map do |url|
        path_parts = url.path.split('/')
        path_parts[path_parts.size - 1]
      end

    result_tweets = []
    tweet_ids.each_slice(100) { |ids| result_tweets += twitter_client.statuses(ids) }
    return result_tweets
  end
end
