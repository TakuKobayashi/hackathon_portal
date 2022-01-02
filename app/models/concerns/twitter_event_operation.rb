require 'objspace'

module TwitterEventOperation
  PAGE_PER = 100
  TWITTER_HOST = 'twitter.com'
  EXCLUDE_CHECK_EVENT_HOSTS = %w[youtu.be youtube.com github.com gamer.ne.jp]

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
    skip_import_event_flag = execute_option_structs.skip_import_event_flag.present?
    default_promote_tweet_score =
      execute_option_structs.default_promote_tweet_score || Promote::ActionTweet::LIKE_ADD_SCORE
    max_tweet_id = execute_option_structs.default_max_tweet_id
    limit_execute_second = execute_option_structs.limit_execute_second || 3600

    retry_count = 0
    tweets = []
    start_time = Time.current

    script_url = GoogleServices.get_location_script_url
    twitter_client = TwitterBot.get_twitter_client(access_token: access_token, access_token_secret: access_token_secret)
    me_twitter = twitter_client.user
    loop do
      break if max_tweet_id.present? && since_tweet_id.present? && max_tweet_id.to_i < since_tweet_id.to_i
      tweets_response = []
      begin
        tweets_response =
          self.find_tweets(
            keywords: keywords,
            access_token: access_token,
            access_token_secret: access_token_secret,
            options: {
              max_id: max_tweet_id,
              since_id: since_tweet_id,
            },
          )
      rescue Twitter::Error::TooManyRequests => e
        Rails.logger.warn "twitter retry since:#{e.rate_limit.reset_in.to_i}"
        retry_count = retry_count + 1
        return []
      end
      retry_count = 0
      take_tweets = tweets_response.take(PAGE_PER)
      take_tweets.sort_by! { |tweet| -tweet.id }
      twitter_url_tweets = self.expanded_tweets_from_twitter_url(tweets: take_tweets, twitter_client: twitter_client)
      tweets = take_tweets + twitter_url_tweets
      tweets.uniq!
      tweets.sort_by! { |tweet| -tweet.id }
      if skip_import_event_flag.blank?
        will_save_events = []
        event_tweets = {}

        # 降順に並んでいるのでreverse_eachをして古い順にデータを作っていくようにする
        tweets.reverse_each do |tweet|
          next if me_twitter.id == tweet.user.id
          quoted_tweet_events = []
          tweet_events = self.build_will_save_twitter_events(tweet: tweet)
          tweet_events.each { |new_event| event_tweets[new_event] = tweet }
          if tweet.quoted_status?
            quoted_tweet_events += self.build_will_save_twitter_events(tweet: tweet.quoted_status)
            quoted_tweet_events.each { |new_event| event_tweets[new_event] = tweet.quoted_status }
          end
          will_save_events += tweet_events
          will_save_events += quoted_tweet_events
        end
        filtered_new_events = will_save_events.uniq { |event| event.url }.select { |event| event.type.present? }
        current_url_events = Event.where(url: filtered_new_events.map(&:url)).includes(:event_detail).index_by(&:url)

        filtered_new_events.each do |event|
          if current_url_events[event.url].blank?
            event.build_location_data(script_url: script_url) if script_url.present?
            begin
              event.save!
              event.import_hashtags!(hashtag_strings: event_tweets[event].hashtags.map(&:text))
            rescue Exception => error
              Rails.logger.warn(["Data save error #{event.attributes} ", error.message].join("\n"))
            end
          end
        end
      end
      self.import_relation_promote_tweets!(
        me_user: me_twitter,
        tweets: tweets,
        default_promote_tweet_score: default_promote_tweet_score,
      )
      max_tweet_id = take_tweets.last.try(:id)
      if tweets.size < PAGE_PER ||
           (max_tweet_id.present? && since_tweet_id.present? && max_tweet_id.to_i < since_tweet_id.to_i) ||
           (Time.current - start_time).second > limit_execute_second
        break
      end
    end
  end

  def self.import_relation_promote_tweets!(
    me_user:,
    tweets: [],
    default_promote_tweet_score: Promote::ActionTweet::LIKE_ADD_SCORE
  )
    all_tweets =
      tweets
        .map do |tweet|
          tweet_arr = []
          if tweet.user.id != me_user.id
            tweet_arr << tweet
            tweet_arr << tweet.quoted_status if tweet.quoted_status?
          end
          tweet_arr
        end
        .flatten
        .uniq
    Promote::ActionTweet.import_tweets!(
      me_user: me_user,
      tweets: all_tweets,
      default_score: default_promote_tweet_score,
    )
    Promote::TwitterUser.import_from_tweets!(tweets: all_tweets)
    Promote::TwitterFriend.import_from_tweets!(me_user: me_user, tweets: all_tweets)
    return all_tweets
  end

  private

  def self.build_will_save_twitter_events(tweet:)
    will_save_events = []
    urls = tweet.urls.map(&:expanded_url)
    return will_save_events if urls.blank?
    urls.each do |url|
      Rails.logger.info(url)

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
      twitter_event.build_informed_from_url
      if twitter_event.connpass? || twitter_event.eventbrite? || twitter_event.doorkeeper? || twitter_event.itchio?
        twitter_event.rebuild_correct_event
      else
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
      end
      will_save_events << twitter_event
    end

    return will_save_events
  end

  def self.find_by_all_relative_events_from_tweets(tweets: [])
    all_twitter_ids = tweets.map { |tweet| [tweet.id.to_s, tweet.quoted_status.id.to_s] }.flatten.select(&:present?)
    twitter_events = Event.twitter.where(event_id: all_twitter_ids)

    all_urls =
      tweets
        .map do |tweet|
          urls = tweet.urls.map { |u| u.expanded_url.to_s }
          urls += tweet.quoted_status.urls.map { |u| u.expanded_url.to_s } if tweet.quoted_status?
          urls
        end
        .flatten
        .uniq

    twitter_events += Event.where(url: all_urls)
    return twitter_events.uniq
  end

  def self.expanded_tweets_from_twitter_url(tweets: [], twitter_client:)
    all_twitter_urls =
      tweets
        .map do |tweet|
          urls = tweet.urls.map { |u| u.expanded_url }
          urls += tweet.quoted_status.urls.map { |u| u.expanded_url } if tweet.quoted_status?
          urls
        end
        .flatten
        .uniq
        .select { |url| url.host == TWITTER_HOST }
    tweet_ids =
      all_twitter_urls.map do |url|
        path_parts = url.path.split('/')
        path_parts[path_parts.size - 1]
      end

    result_tweets = []
    tweet_ids.each_slice(Twitter::REST::Tweets::MAX_TWEETS_PER_REQUEST) do |ids|
      begin
        result_tweets += twitter_client.statuses(ids)
      rescue Twitter::Error::TooManyRequests => e
        Rails.logger.warn(
          ['TooManyRequest expanded_tweets_from_twitter_url Error:', e.rate_limit.reset_in, 's'].join(' '),
        )
        break
      rescue Twitter::Error::NotFound => e
        Rails.logger.warn(['NotFound expanded_tweets_from_twitter_url Error:', e.rate_limit.reset_in, 's'].join(' '))
        break
      rescue HTTP::ConnectionError => e
        Rails.logger.warn(['HTTP::ConnectionError expanded_tweets_from_twitter_url Error'].join(' '))
      end
    end
    return result_tweets
  end
end
