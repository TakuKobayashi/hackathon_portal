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
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

require 'google/apis/urlshortener_v1'

class Event < ApplicationRecord
  geocoded_by :address, latitude: :lat, longitude: :lon
  after_validation :geocode

  before_save do
    self.address = Charwidth.normalize(self.address)
  end

  HACKATHON_KEYWORDS = ["hackathon", "ッカソン", "jam", "ジャム", "アイディアソン", "アイデアソン", "ideathon"]

  def self.import_events!
    Connpass.import_events!
    Doorkeeper.import_events!
    Atnd.import_events!
  end

  def hackathon_event?
    sanitized_title = Sanitizer.basic_sanitize(self.title).downcase
    return Event::HACKATHON_KEYWORDS.any?{|word| sanitized_title.include?(word) }
  end

  def generate_tweet_text
     tweet_words = [self.title, self.short_url, self.started_at.strftime("%Y年%m月%d日")]
     if self.limit_number.present?
       tweet_words << "定員#{self.limit_number}人"
     end
     tweet_words += ["#hackathon", "#ハッカソン"]
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
    og = OpenGraph.new(self.url)
    words = [
      "### [#{self.title}](#{self.url})",
    ]
    if og.images.present?
      image_url = og.images.first
      # 画像じゃないものも含まれていることもあるので分別する
      fi = FastImage.new(image_url.to_s)
      if fi.type.present?
        width, height = fi.size
        size_text = ApplicationRecord.calc_resize_text(width: width, height: height, max_length: 200)
        resize_width, resize_height = size_text.split("x")
        words << ActionController::Base.helpers.image_tag(image_url, {width: resize_width, height: resize_height})
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
    if (1..3).cover?(month)
      return number + 103
    elsif (4..6).cover?(month)
      return number + 406
    elsif (7..9).cover?(month)
      return number + 709
    elsif (10..12).cover?(month)
      return number + 1012
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
