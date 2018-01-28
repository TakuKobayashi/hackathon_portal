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
#  hash_tag          :string(255)
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

require 'google/apis/urlshortener_v1'

class Event < ApplicationRecord
  has_many :summaries, as: :resource, class_name: 'Ai::ResourceSummary'
  has_many :hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'

  HACKATHON_KEYWORDS = ["hackathon", "ッカソン", "jam", "ジャム", "アイディアソン", "アイデアソン", "ideathon", "合宿"]
  DEVELOPMENT_CAMP_KEYWORDS = ["開発", "プログラム", "プログラミング", "ハンズオン", "勉強会", "エンジニア", "デザイナ", "デザイン", "ゲーム"]
  HACKATHON_CHECK_SEARCH_KEYWORD_POINTS = {
    "合宿" => 2,
    "hackathon" => 2,
    "ハッカソン" => 2,
    "ハック" => 1,
    "アイディアソン" => 2,
    "アイデアソン" => 2,
    "ideathon" => 2,
    "ゲームジャム" => 2,
    "hack day" => 2,
    "game jam" => 2
  }

  def self.import_events!
    Connpass.import_events!
    Doorkeeper.import_events!
    Atnd.import_events!
    Peatix.import_events!
  end

  def hackathon_event?
    if self.type == "SelfPostEvent"
      return true
    end
    appear_count = 0
    Event::HACKATHON_CHECK_SEARCH_KEYWORD_POINTS.each do |keyword, point|
      sanitized_title = Sanitizer.basic_sanitize(self.title.to_s).downcase
      appear_count += sanitized_title.scan(keyword).size * point * 3
      sanitized_description = Sanitizer.basic_sanitize(self.description.to_s).downcase
      appear_count += sanitized_description.scan(keyword).size * point
      if appear_count >= 6
        if keyword == "合宿"
          return development_camp?(keyword: keyword)
        else
          return true
        end
      end
    end
    return false
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

  def set_location_data
    if self.address.present? && self.lat.blank? && self.lon.blank?
      geo_result = Geocoder.search(self.address).first
      if geo_result.present?
        self.lat = geo_result.latitude
        self.lon = geo_result.longitude
      end
    elsif self.address.blank? && self.lat.present? && self.lon.present?
      geo_result = Geocoder.search([self.lat, self.lon].join(",")).first
      if geo_result.present?
        self.address = Sanitizer.scan_japan_address(geo_result.address).join
      end
    end
    if self.address.present?
      self.address = Charwidth.normalize(self.address)
    end
  end

  def import_hash_tags!(hashtags: [])
    sanitized_hashtags = [hashtags].flatten.map do |hashtag|
      htag = Sanitizer.basic_sanitize(hashtag.to_s)
      Sanitizer.delete_sharp(htag).split(/[\s　]/)
    end.flatten
    return false if sanitized_hashtags.blank?
    ai_hashtags = Ai::Hashtag.where(hashtag: sanitized_hashtags).index_by(&:hashtag)
    sanitized_hashtags.each do |h|
      if ai_hashtags[h].present?
        aih = ai_hashtags[h]
      else
        aih = Ai::Hashtag.new(hashtag: h)
      end
      aih.update!(appear_count: aih.appear_count + 1)
      self.hashtags.find_or_create_by(hashtag_id: aih.id)
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
    if self.hash_tag.present?
      hashtags = self.hash_tag.to_s.split(" #")
      tweet_words += hashtags.map{|hashtag| "#" + hashtag.to_s }
    end
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
    return tweet_words.join("\n")
  end

  def generate_google_map_url
    return "https://www.google.co.jp/maps?q=#{self.lat},#{self.lon}"
  end

  def generate_google_map_static_image_url
    apiconfig = YAML.load(File.open(Rails.root.to_s + "/config/apiconfig.yml"))
    return "https://maps.googleapis.com/maps/api/staticmap?zoom=15&center=#{self.lat},#{self.lon}&key=#{apiconfig["google"]["apikey"]}&size=185x185"
  end

  def generate_qiita_cell_text
    dom = RequestParser.request_and_parse_html(url: self.url, options: {:follow_redirect => true})
    og_image_dom = dom.css("meta[@property = 'og:image']").first
    words = [
      "### [#{self.title}](#{self.url})",
    ]
    if og_image_dom.present?
      image_url = og_image_dom["content"].to_s
      # 画像じゃないものも含まれていることもあるので分別する
      fi = FastImage.new(image_url.to_s)
      if fi.type.present?
        width, height = fi.size
        size_text = AdjustImage.calc_resize_text(width: width, height: height, max_length: 300)
        resize_width, resize_height = size_text.split("x")
        words << (ActionController::Base.helpers.image_tag(image_url, {width: resize_width, height: resize_height, alt: self.title}) + "\n")
      end
    end
    words += [
      self.started_at.strftime("%Y年%m月%d日"),
      self.place,
      "[#{self.address}](#{self.generate_google_map_url})",
      "![#{self.address}](#{generate_google_map_static_image_url})"
    ]
    if self.limit_number.present?
      words << "定員#{self.limit_number}人"
    end
    if self.type == "Atnd" || self.type == "Connpass" || self.type == "Doorkeeper"
      if self.ended_at.present? && self.ended_at < Time.current
        words << "#{self.attend_number}人が参加しました"
      else
        words << "#{Time.now.strftime("%Y年%m月%d日 %H:%M")}現在 #{self.attend_number}人参加中"
        if self.limit_number.present?
          remain_number = self.limit_number - self.attend_number
          if remain_number > 0
            words << "<font color=\"#FF0000;\">あと残り#{remain_number}人</font> 参加可能"
          else
            words << "今だと補欠登録されると思います。<font color=\"#FF0000\">(#{self.substitute_number}人が補欠登録中)</font>"
          end
        end
      end
    end
    return words.join("\n")
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
    apiconfig = YAML.load(File.open(Rails.root.to_s + "/config/apiconfig.yml"))
    service = Google::Apis::UrlshortenerV1::UrlshortenerService.new
    service.key = apiconfig["google"]["apikey"]
    url_obj = Google::Apis::UrlshortenerV1::Url.new
    url_obj.long_url = self.url
    result = service.insert_url(url_obj)
    update!(shortener_url: result.id)
  end
end
