module EventCommon
  BITLY_SHORTEN_API_URL = 'https://api-ssl.bitly.com/v4/shorten'

  def merge_event_attributes(attrs: {})
    ops = OpenStruct.new(attrs.reject { |key, value| value.nil? })

    if ops.started_at.present? && ops.started_at.is_a?(String)
      parsed_started_at = DateTime.parse(ops.started_at)
      ops.started_at = parsed_started_at if self.started_at.try(:utc) != parsed_started_at.try(:utc)
    end

    if ops.ended_at.present? && ops.ended_at.is_a?(String)
      parsed_ended_at = DateTime.parse(ops.ended_at)
      ops.ended_at = parsed_ended_at if self.ended_at.try(:utc) != parsed_ended_at.try(:utc)
    end
    if self.lat.present? && self.lon.present?
      ops.delete_field(:lat) unless ops.lat.nil?
      ops.delete_field(:lon) unless ops.lon.nil?
    end
    self.attributes = self.attributes.merge(ops.to_h)
    self.build_location_data
  end

  def build_location_data
    script_url = 'https://script.google.com/macros/s/AKfycbxM1zm-Ep6jsV87pi5U9UQJQM4YvU2BHiCOghOV90wYCae3mtNfrz3JIQLWBxSMoJF0zA/exec'
    if self.address.present? && self.lat.blank? && self.lon.blank?
      geo_result =
        RequestParser.request_and_parse_json(url: script_url, params: { address: self.address }, options: { follow_redirect: true })
      self.lat = geo_result['latitude']
      self.lon = geo_result['longitude']
    elsif self.address.blank? && self.lat.present? && self.lon.present?
      geo_result =
        RequestParser.request_and_parse_json(
          url: script_url, params: { latitude: self.lat, longitude: self.lon }, options: { follow_redirect: true }
        )
      self.lat = geo_result['latitude']
      self.lon = geo_result['longitude']
      self.address = geo_result['address']
    end
    if self.address.present?
      self.address = Charwidth.normalize(self.address).strip
    else
      self.address = ''
    end
  end

  def build_informed_from_url
    aurl = Addressable::URI.parse(self.url)
    if aurl.host.include?('connpass.com')
      self.informed_from = :connpass
    elsif aurl.host.include?('peatix.com')
      self.informed_from = :peatix
    elsif aurl.host.include?('doorkeeper')
      self.informed_from = :doorkeeper
    elsif aurl.host.include?('atnd')
      self.informed_from = :atnd
    elsif aurl.host.include?('meetup.com')
      self.informed_from = :meetup
    end
  end

  def build_from_website
    #TODO 開催日時のスクレイピング
    dom = RequestParser.request_and_parse_html(url: self.url, options: { follow_redirect: true })
    self.title = dom.try(:title).to_s.truncate(140)
    dom.css('meta').each do |meta_dom|
      dom_attrs = OpenStruct.new(meta_dom.to_h)
      if self.description.blank?
        if dom_attrs.name == 'description'
          self.description = dom_attrs.content
        elsif dom_attrs.property == 'og:description'
          self.description = dom_attrs.content
        end
      end
    end
    #      sanitized_body_html = Sanitizer.basic_sanitize(dom.css("body").to_html)
    #      scaned_urls = Sanitizer.scan_urls(sanitized_body_html)

    sanitized_body_text = Sanitizer.basic_sanitize(dom.css('body').to_html)
    address_canididates = Sanitizer.scan_japan_address(sanitized_body_text)

    self.address = Sanitizer.match_address_text(address_canididates.first.to_s).to_s
    self.place = self.address
    self.started_at = Sanitizer.basic_sanitize(dom.css('body').to_html)
  end

  def import_hashtags!(hashtag_strings: [])
    sanitized_hashtags =
      [hashtag_strings].flatten.map do |hashtag|
        htag = Sanitizer.basic_sanitize(hashtag.to_s)
        Sanitizer.delete_sharp(htag).split(/[\s　,]/).select(&:present?)
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
    return Sanitizer.scan_hash_tags(Nokogiri::HTML.parse(self.description.to_s).text).join(' ')
  end

  def generate_qiita_cell_text
    words = ["### [#{self.title}](#{self.url})"]
    image_html = self.og_image_html
    words << (image_html + "\n") if image_html.present?

    words += [self.started_at.strftime('%Y年%m月%d日'), self.place, "[#{self.address}](#{self.generate_google_map_url})"]
    words << "定員#{self.limit_number}人" if self.limit_number.present?

    if self.attend_number >= 0
      if self.ended_at.present? && self.ended_at < Time.current
        words << "#{self.attend_number}人が参加しました"
      else
        words << "#{Time.now.strftime('%Y年%m月%d日 %H:%M')}現在 #{self.attend_number}人参加中"

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

  def og_image_html
    # すでにイベントが閉鎖しているのだからその後の処理をやらないようにしてみる
    if self.closed?
      return ''
    end
    image_url = self.get_og_image_url
    if image_url.present?
      fi = FastImage.new(image_url.to_s)
      width, height = fi.size
      size_text = AdjustImage.calc_resize_text(width: width, height: height, max_length: 300)
      resize_width, resize_height = size_text.split('x')
      return ActionController::Base.helpers.image_tag(image_url, { width: resize_width, height: resize_height, alt: self.title })
    end
    return ''
  end

  def generate_google_map_url
    return "https://www.google.co.jp/maps?q=#{self.lat},#{self.lon}"
  end

  def generate_google_map_static_image_url
    return(
      "https://maps.googleapis.com/maps/api/staticmap?zoom=15&center=#{self.lat},#{self.lon}&key=#{
        ENV.fetch('GOOGLE_API_KEY', '')
      }&size=185x185"
    )
  end

  def generate_google_map_embed_tag
    embed_url = Addressable::URI.parse('https://maps.google.co.jp/maps')
    query_hash = { ll: [self.lat, self.lon].join(','), output: 'embed', z: 16 }
    if self.place.present?
      query_hash[:q] = self.place
    elsif self.address.present?
      query_hash[:q] = self.address
    end
    embed_url.query_values = query_hash
    return(
      ActionController::Base.helpers.raw(
        "<iframe width=\"400\" height=\"300\" frameborder=\"0\" scrolling=\"yes\" marginheight=\"0\" marginwidth=\"0\" src=\"#{
          embed_url.to_s
        }\"></iframe>"
      )
    )
  end

  def get_og_image_url
    dom = RequestParser.request_and_parse_html(url: self.url, options: { follow_redirect: true })
    og_image_dom = dom.css("meta[@property = 'og:image']").first

    # 画像じゃないものも含まれていることもあるので分別する

    if og_image_dom.present?
      image_url = og_image_dom['content'].to_s

      fi = FastImage.new(image_url.to_s)
      return image_url.to_s if fi.type.present?
    end
    return nil
  end

  def short_url
    convert_to_short_url! if shortener_url.blank?
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

  def url_activate?
    http_client = HTTPClient.new
    begin
      response = http_client.get(self.url)
      if 400 <= response.status && response.status < 500
        return false
      end
    rescue SocketError, HTTPClient::ConnectTimeoutError, HTTPClient::BadResponseError, Addressable::URI::InvalidURIError => e
      return false
    end
    return true
  end

  def get_short_url
    result =
      RequestParser.request_and_parse_json(
        url: BITLY_SHORTEN_API_URL,
        method: :post,
        header: { 'Authorization' => "Bearer #{ENV.fetch('BITLY_ACCESS_TOKEN', '')}", 'Content-Type' => 'application/json' },
        body: { long_url: self.url }.to_json,
        options: { follow_redirect: true }
      )
    if result['id'].present?
      return 'https://' + result['id']
    else
      return nil
    end
    #    service = Google::Apis::UrlshortenerV1::UrlshortenerService.new
    #    service.key = ENV.fetch('GOOGLE_API_KEY', '')
    #    url_obj = Google::Apis::UrlshortenerV1::Url.new
    #    url_obj.long_url = self.url
    #    result = service.insert_url(url_obj)
    #    return result.id
  end
end
