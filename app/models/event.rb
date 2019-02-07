# == Schema Information
#
# Table name: events
#
#  id                    :integer          not null, primary key
#  event_id              :string(255)
#  type                  :string(255)
#  title                 :string(255)      not null
#  url                   :string(255)      not null
#  shortener_url         :string(255)
#  description           :text(65535)
#  started_at            :datetime         not null
#  ended_at              :datetime
#  limit_number          :integer
#  address               :string(255)      not null
#  place                 :string(255)      not null
#  lat                   :float(24)
#  lon                   :float(24)
#  cost                  :integer          default(0), not null
#  max_prize             :integer          default(0), not null
#  currency_unit         :string(255)      default("円"), not null
#  owner_id              :string(255)
#  owner_nickname        :string(255)
#  owner_name            :string(255)
#  attend_number         :integer          default(0), not null
#  substitute_number     :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  location_image_binary :binary(16777215)
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

  has_many :summaries, as: :resource, class_name: 'Ai::ResourceSummary'
  has_many :resource_hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'
  has_many :hashtags, through: :resource_hashtags, source: :hashtag
  accepts_nested_attributes_for :hashtags

  HACKATHON_KEYWORDS = ["hackathon", "ッカソン", "jam", "ジャム", "アイディアソン", "アイデアソン", "ideathon", "合宿"]
  DEVELOPMENT_CAMP_KEYWORDS = ["開発", "プログラム", "プログラミング", "ハンズオン", "勉強会", "エンジニア", "デザイナ", "デザイン", "ゲーム"]
  HACKATHON_CHECK_SEARCH_KEYWORD_POINTS = {
    "hackathon" => 2,
    "ハッカソン" => 2,
    "hack day" => 2,
    "アイディアソン" => 2,
    "アイデアソン" => 2,
    "ideathon" => 2,
    "ゲームジャム" => 2,
    "gamejam" => 2,
    "game jam" => 2,
    "合宿" => 2,
    "ハック" => 1
  }

  HACKATHON_KEYWORD_CALENDER_INDEX = {
    "hackathon" => 1,
    "ハッカソン" => 1,
    "hack day" => 1,
    "アイディアソン" => 2,
    "アイデアソン" => 2,
    "ideathon" => 2,
    "ゲームジャム" => 3,
    "gamejam" => 3,
    "game jam" => 3,
    "合宿" => 4,
    "ハック" => 1
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
    if self.type == "SelfPostEvent"
      return true
    end
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
        if keyword == "合宿" && !development_camp?(keyword: keyword)
          return nil
        end
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
      check_word = Event::HACKATHON_KEYWORDS.detect{|word| sanitized_title.include?(word)}
    end
    if check_word == "合宿"
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

  def merge_attributes_and_set_location_data(attrs: {})
    ops = OpenStruct.new(attrs.reject{|key, value| value.nil? })
    if ops.started_at.present?
      ops.started_at = DateTime.parse(ops.started_at)
    end
    if ops.ended_at.present?
      ops.ended_at = DateTime.parse(ops.ended_at)
    end
    self.attributes = self.attributes.merge(ops.to_h)
    self.set_location_data
  end

  def set_location_data
    if self.address.present? && self.lat.blank? && self.lon.blank?
      geo_result = RequestParser.request_and_parse_json(
        url: "https://maps.googleapis.com/maps/api/geocode/json",
        params: {address: self.address, language: "ja", key: ENV.fetch('GOOGLE_API_KEY', '')}
        )["results"].first
      #geo_result = Geocoder.search(self.address).first
      if geo_result.present?
        self.lat = geo_result["geometry"]["location"]["lat"]
        self.lon = geo_result["geometry"]["location"]["lng"]
#        self.lat = geo_result.latitude
#        self.lon = geo_result.longitude
      end
    elsif self.address.blank? && self.lat.present? && self.lon.present?
      geo_result = RequestParser.request_and_parse_json(
        url: "https://maps.googleapis.com/maps/api/geocode/json",
        params: {latlng: [self.lat, self.lon].join(","), language: "ja", key: ENV.fetch('GOOGLE_API_KEY', '')}
        )["results"].first
#      geo_result = Geocoder.search([self.lat, self.lon].join(",")).first
      if geo_result.present?
        searched_address = Charwidth.normalize(Sanitizer.scan_japan_address(geo_result["formatted_address"]).join).
          gsub(/^[0-9【】、。《》「」〔〕・（）［］｛｝！＂＃＄％＆＇＊＋，－．／：；＜＝＞？＠＼＾＿｀｜￠￡￣\(\)\[\]<>{},!? \.\-\+\\~^='&%$#\"\'_\/;:*‼•一]/, "").
          strip.
          split(" ").first
        if searched_address.present?
          self.address = searched_address
        end
        #self.address = Sanitizer.scan_japan_address(geo_result.address).join
      end
    end
    if self.address.present?
      self.address = Charwidth.normalize(self.address).strip
    end
  end

  def import_hashtags!(hashtag_strings: [])
    sanitized_hashtags = [hashtag_strings].flatten.map do |hashtag|
      htag = Sanitizer.basic_sanitize(hashtag.to_s)
      Sanitizer.delete_sharp(htag).split(/[\s　,]/).select{|h| h.present? }
    end.flatten
    return false if sanitized_hashtags.blank?
    ai_hashtags = Ai::Hashtag.where(hashtag: sanitized_hashtags).index_by(&:hashtag)
    sanitized_hashtags.each do |h|
      if ai_hashtags[h].present?
        aih = ai_hashtags[h]
      else
        aih = Ai::Hashtag.new(hashtag: h)
      end
      aih.save!
      self.resource_hashtags.find_or_create_by(hashtag_id: aih.id)
    end
  end

  def search_hashtags
    return Sanitizer.scan_hash_tags(Nokogiri::HTML.parse(self.description.to_s).text).join(" ")
  end

  def generate_tweet_text
    tweet_words = [self.title, self.short_url, self.started_at.strftime("%Y年%m月%d日")]
    if self.limit_number.present?
      tweet_words << "定員#{self.limit_number}人"
    end
    hs = self.hashtags.map(&:hashtag).map{|hashtag| "#" + hashtag.to_s }
    tweet_words += hs
    if development_camp?
      tweet_words += ["#開発合宿", "#合宿"]
    else
      tweet_words += ["#hackathon", "#ハッカソン"]
    end
    text_size = 0
    tweet_words.select! do |text|
      text_size += text.size
      text_size <= 140
    end
    return tweet_words.uniq.join("\n")
  end

  def generate_google_map_url
    return "https://www.google.co.jp/maps?q=#{self.lat},#{self.lon}"
  end

  def generate_google_map_static_image_url
    return "https://maps.googleapis.com/maps/api/staticmap?zoom=15&center=#{self.lat},#{self.lon}&key=#{ENV.fetch('GOOGLE_API_KEY', '')}&size=185x185"
  end

  def get_og_image_url
    dom = RequestParser.request_and_parse_html(url: self.url, options: {:follow_redirect => true})
    og_image_dom = dom.css("meta[@property = 'og:image']").first
    if og_image_dom.present?
      image_url = og_image_dom["content"].to_s
      # 画像じゃないものも含まれていることもあるので分別する
      fi = FastImage.new(image_url.to_s)
      if fi.type.present?
        return image_url.to_s
      end
    end
    return nil
  end

  def short_url
    if shortener_url.blank?
      convert_to_short_url!
    end
    return self.shortener_url
  end

  # {年}{開始月}{終了月}になるように番号を形成する
  def season_date_number
    number = self.started_at.year * 10000
    month = self.started_at.month
    if (1..2).cover?(month)
      return number + 102
    elsif (3..4).cover?(month)
        return number + 304
    elsif (5..6).cover?(month)
      return number + 506
    elsif (7..8).cover?(month)
      return number + 708
    elsif (9..10).cover?(month)
      return number + 910
    elsif (11..12).cover?(month)
      return number + 1112
    end
  end

  def convert_to_short_url!
    update!(shortener_url: self.get_short_url)
  end

  def get_short_url
    service = Google::Apis::UrlshortenerV1::UrlshortenerService.new
    service.key = ENV.fetch('GOOGLE_API_KEY', '')
    url_obj = Google::Apis::UrlshortenerV1::Url.new
    url_obj.long_url = self.url
    result = service.insert_url(url_obj)
    return result.id
  end
end
