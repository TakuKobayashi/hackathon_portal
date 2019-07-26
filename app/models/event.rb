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

require 'google/apis/urlshortener_v1'

class Event < ApplicationRecord
  include EventCommon

  enum judge_state: { before_judge: 0, maybe_hackathon: 1, maybe_development_camp: 2, another_development_event: 3, unknown: 9 }

  has_many :summaries, as: :resource, class_name: 'Ai::ResourceSummary'
  has_many :resource_hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'
  has_many :hashtags, through: :resource_hashtags, source: :hashtag
  accepts_nested_attributes_for :hashtags

  HACKATHON_KEYWORDS = %w[hackathon ッカソン jam ジャム アイディアソン アイデアソン ideathon 合宿]
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
    '合宿' => 2,
    'ハック' => 1
  }

  HACKATHON_KEYWORD_CALENDER_INDEX = {
    'hackathon' => 1,
    'ハッカソン' => 1,
    'hack day' => 1,
    'アイディアソン' => 2,
    'アイデアソン' => 2,
    'ideathon' => 2,
    'ゲームジャム' => 3,
    'gamejam' => 3,
    'game jam' => 3,
    '合宿' => 4,
    'ハック' => 1
  }

  before_save do
    if self.url.size > 255
      shorted_url = self.get_short_url
      self.url = shorted_url
      self.shortener_url = shorted_url
    end
  end

  def self.import_events!
    Connpass.import_events!
    Doorkeeper.import_events!
    Atnd.import_events!
    Peatix.import_events!
    Meetup.import_events!
  end

  def hackathon_event?
    return true if self.type == 'SelfPostEvent'
    return hackathon_event_hit_keyword.present?
  end

  def hackathon_event_hit_keyword
    appear_count = 0
    Event::HACKATHON_CHECK_SEARCH_KEYWORD_POINTS.each do |keyword, point|
      sanitized_title = Sanitizer.basic_sanitize(self.title.to_s).downcase
      appear_count += sanitized_title.scan(keyword).size * point * 3
      sanitized_description = Sanitizer.basic_sanitize(self.description.to_s).downcase
      appear_count += sanitized_description.scan(keyword).size * point

      if appear_count >= 6
        return nil if keyword == '合宿' && !development_camp?(keyword: keyword)
        return keyword
      end
    end
    return nil
  end

  def development_camp?(keyword: nil)
    sanitized_title = Sanitizer.basic_sanitize(self.title).downcase
    if keyword.present?
      check_word = keyword
    else
      check_word = Event::HACKATHON_KEYWORDS.detect { |word| sanitized_title.include?(word) }
    end
    if check_word == '合宿'
      sanitized_description = Sanitizer.basic_sanitize(self.description.to_s).downcase
      appear_count = 0
      Event::DEVELOPMENT_CAMP_KEYWORDS.each do |keyword|
        appear_count += sanitized_title.scan(keyword).size * 2
        appear_count += sanitized_description.scan(keyword).size
      end
      return appear_count >= 2
    else
      return false
    end
  end

  def generate_tweet_text
    tweet_words = [self.title, self.short_url, self.started_at.strftime('%Y年%m月%d日')]
    tweet_words << "定員#{self.limit_number}人" if self.limit_number.present?
    hs = self.hashtags.map(&:hashtag).map { |hashtag| '#' + hashtag.to_s }
    tweet_words += hs
    if development_camp?
      tweet_words += %w[#開発合宿 #合宿]
    else
      tweet_words += %w[#hackathon #ハッカソン]
    end
    text_size = 0
    tweet_words.select! do |text|
      text_size += text.size
      text_size <= 140
    end
    return tweet_words.uniq.join("\n")
  end
end
