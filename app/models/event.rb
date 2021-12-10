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
#  started_at        :datetime         not null
#  ended_at          :datetime         not null
#  limit_number      :integer
#  address           :string(255)
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
#  informed_from     :integer          default("web"), not null
#  state             :integer          default("active"), not null
#
# Indexes
#
#  index_events_on_ended_at                    (ended_at)
#  index_events_on_event_id_and_informed_from  (event_id,informed_from)
#  index_events_on_started_at                  (started_at)
#  index_events_on_url                         (url)
#

class Event < ApplicationRecord
  include EventCommon

  enum state: { active: 0, unactive: 1, closed: 2 }
  enum informed_from: {
         web: 0,
         connpass: 1,
         atnd: 2,
         doorkeeper: 3,
         peatix: 4,
         meetup: 5,
         google_form: 6,
         twitter: 7,
         devpost: 8,
         eventbrite: 9,
         itchio: 10,
       }

  has_one :event_detail, class_name: 'EventDetail', foreign_key: 'event_id'
  has_one :event_calendar_bot, as: :from, class_name: 'EventCalendarBot'
  has_one :twitter_bot, as: :from, class_name: 'TwitterBot'
  has_many :resource_hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'
  has_many :hashtags, through: :resource_hashtags, source: :hashtag
  accepts_nested_attributes_for :hashtags
  accepts_nested_attributes_for :event_detail, :allow_destroy => true

  after_initialize :initialize_event_detail, :if => :new_record?

  with_options to: :event_detail do |attr|
    attr.delegate :description
    attr.delegate :og_image_info
  end

  TWITTER_HACKATHON_KEYWORDS = %w[
    hackathon
    ッカソン
    gamejam
    アイディアソン
    アイデアソン
    ideathon
    開発合宿
    はっかそん
    アプリコンテスト
    開発コンテスト
    "App
    Challenge"
    "Application
    Challenge"
  ]
  TWITTER_ADDITIONAL_PROMOTE_KEYWORDS = %w[エンジニア developer デザイナ]
  DEVELOPMENT_CAMP_KEYWORDS = %w[開発 プログラム プログラミング ハンズオン 勉強会 エンジニア デザイナ デザイン ゲーム]
  HACKATHON_CHECK_SEARCH_KEYWORD_POINTS = {
    'hackathon' => 2,
    'ハッカソン' => 2,
    'hack day' => 2,
    'アイディアソン' => 2,
    'アイデアソン' => 2,
    'ideathon' => 2,
    'ゲームジャム' => 2,
    'gamejam' => 2,
    'game jam' => 2,
  }

  before_save do
    if self.url.size > 255
      shorted_url = self.get_short_url
      self.url = shorted_url
      self.shortener_url = shorted_url
    end
  end

  def self.google_form_spreadsheet_id
    return '1KbKcNoUXThP5pMz_jDne7Mcvl1aFdUHeV9cDNI1OUfY'
  end

  def self.import_events!
    # マルチスレッドで処理を実行するとCircular dependency detected while autoloading constantというエラーが出るのでその回避のためあらかじめeager_loadする
    Rails.application.eager_load!
    operation_modules = HackathonEvent::SEARCH_OPERATION_KEYWORDS.keys
    Parallel.each(operation_modules, in_threads: operation_modules.size) do |operation_module|
      keywords = HackathonEvent::SEARCH_OPERATION_KEYWORDS[operation_module]
      operation_module.import_events_from_keywords!(keywords: keywords)
    end
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start
    GoogleFormEventOperation.load_and_imoport_events!(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
  end

  def self.import_events_from_twitter!
    TwitterEventOperation.import_events_from_keywords!(
      keywords: Event::TWITTER_HACKATHON_KEYWORDS,
      options: {
        limit_execute_second: 3600,
        default_max_tweet_id: nil,
      },
    )
  end

  def distribute_event_type
    # TODO アイディアソンもここで振り分けたい
    if self.hackathon_event?
      self.type = HackathonEvent.to_s
    elsif self.development_camp?
      self.type = DevelopmentCampEvent.to_s
    else
      self.type = nil
    end
  end

  # TODO データの取得先に応じて判定ロジックを変えたい
  def hackathon_event?
    sanitized_title = Sanitizer.basic_sanitize(self.title.to_s).downcase
    score_rate = self.check_score_rate
    score = 0
    direct_keywords = [
      'hackathon',
      'ハッカソン',
      'hack day',
      'アイディアソン',
      'アイデアソン',
      'ideathon',
      'ゲームジャム',
      'gamejam',
      'game jam',
    ]
    direct_keywords.each do |word|
      if sanitized_title.include?(word)
        score += 1
        break
      end
    end
    return true if (score * score_rate) >= 1

    sanitized_description = Sanitizer.basic_sanitize(self.description.to_s).downcase
    direct_keywords.each do |keyword|
      score += sanitized_description.scan(keyword).size * 0.35
      return true if (score * score_rate) >= 1
    end
    return false
  end

  def development_camp?
    sanitized_title = Sanitizer.basic_sanitize(self.title.to_s).downcase
    score = 0
    score_rate = self.check_score_rate
    camp_keywords = %w[合宿 キャンプ camp]
    camp_keywords.each do |word|
      if sanitized_title.include?(word)
        score += 0.5
        break
      end
    end

    development_keywords = %w[開発 プログラム プログラミング ハンズオン 勉強会 エンジニア デザイナ デザイン ゲーム]
    development_keywords.each do |word|
      if sanitized_title.include?(word)
        score += 0.5
        break
      end
    end
    return true if (score * score_rate) >= 1
    sanitized_description = Sanitizer.basic_sanitize(self.description.to_s).downcase
    (camp_keywords + development_keywords).each do |keyword|
      score += sanitized_description.scan(keyword).size * 0.2
      return true if (score * score_rate) >= 1
    end
    return false
  end

  def default_hashtags
    return %w[#hackathon #ハッカソン]
  end

  def generate_tweet_text
    tweet_words = [self.title, self.output_url, self.started_at.strftime('%Y年%m月%d日')]
    tweet_words << "定員#{self.limit_number}人" if self.limit_number.present?
    hs = self.hashtags.map(&:hashtag).map { |hashtag| '#' + hashtag.to_s }
    tweet_words += hs
    tweet_words += self.default_hashtags
    text_size = 0
    tweet_words.select! do |text|
      text_size += text.size
      text_size <= 140
    end
    return tweet_words.uniq.join("\n")
  end

  def output_url
    if self.short_url.present?
      return self.short_url
    else
      return self.url
    end
  end

  def tweet_url
    return @tweet_url if @tweet_url.present?
    if self.twitter? && self.event_id.present?
      twitter_client =
        TwitterBot.get_twitter_client(
          access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
          access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
        )
      tweet = nil
      begin
        tweet = twitter_client.status(self.event_id)
      rescue Exception => e
      end
      @tweet_url = tweet.try(:url).to_s
      return @tweet_url
    end
    return ''
  end

  def og_image_url=(image_url)
    fi = FastImage.new(image_url.to_s)

    # 画像じゃないものも含まれていることもあるので分別する
    return {} if fi.type.blank?
    width, height = fi.size
    self.event_detail.og_image_info = { image_url: image_url.to_s, width: width.to_i, height: height.to_i, type: fi.type }
    return self.event_detail.og_image_info
  end

  def og_image_url
    current_og_image_hash = self.og_image_info || {}
    return current_og_image_hash['image_url']
  end

  def tweet_url=(tweet_status_url)
    @tweet_url = tweet_status_url
  end

  # scoreをかけることで判定を渋くする
  def check_score_rate
    if @score_rate.present?
      return @score_rate.to_f
    else
      return 1.0
    end
  end

  def check_score_rate=(score_rate)
    @score_rate = score_rate
  end

  def self.preset_tweet_urls!(events: [])
    event_tweet_ids = events.select(&:twitter?).map(&:event_id)
    twitter_client =
      TwitterBot.get_twitter_client(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )

    # Twitter APIの仕様により100件ずつ設定する
    event_tweet_ids.each_slice(Twitter::REST::Tweets::MAX_TWEETS_PER_REQUEST) do |tweet_ids|
      event_tweets = twitter_client.statuses(tweet_ids)
      event_tweets.each do |event_tweet|
        event = events.detect { |event| event.twitter? && event.event_id == event_tweet.id.to_s }
        event.tweet_url = event_tweet.url.to_s
      end
    end
  end

  def self.remove_all_deplicate_events!
    remove_event_ids_set = Set.new
    Event.find_each do |event|
      next if remove_event_ids_set.include?(event.id)
      will_remove_events = Event.where.not(id: event.id).where(url: event.url)
      will_remove_events.each do |event|
        event.revert!
        remove_event_ids_set << event.id
      end
    end
    EventCalendarBot.remove_all_deplicate_events
  end

  def revert!
    remove_twitter_bot = TwitterBot.find_by(from: self)
    if remove_twitter_bot.present?
      remove_twitter_bot.reject_tweet!(
        access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
        access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
      )
    end
    remove_calendar_bot = EventCalendarBot.find_by(from: self)
    if remove_calendar_bot.present?
      remove_calendar_bot.remove_calender!(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    end
    QiitaBot.remove_event!(event: self)
    BloggerBot.remove_event!(
      event: self,
      blogger_blog_url: 'https://hackathonportal.blogspot.com/',
      refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''),
    )
    self.destroy!
  end

  private
  def initialize_event_detail
    self.build_event_detail if self.new_record?
  end
end
