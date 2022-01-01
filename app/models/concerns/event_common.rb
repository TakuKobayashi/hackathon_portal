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
    self.distribute_event_type
  end

  def build_location_data(script_url: '')
    if self.address.present? && self.lat.blank? && self.lon.blank?
      geo_result =
        RequestParser.request_and_parse_json(
          url: script_url,
          params: {
            address: self.address,
          },
          options: {
            follow_redirect: true,
          },
        )
      self.lat = geo_result['latitude']
      self.lon = geo_result['longitude']
    elsif self.address.blank? && self.lat.present? && self.lon.present?
      geo_result =
        RequestParser.request_and_parse_json(
          url: script_url,
          params: {
            latitude: self.lat,
            longitude: self.lon,
          },
          options: {
            follow_redirect: true,
          },
        )
      self.lat = geo_result['latitude']
      self.lon = geo_result['longitude']
      self.address = geo_result['address']
    end
    self.address = Charwidth.normalize(self.address).strip if self.address.present?
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
    elsif aurl.host.include?('devpost.com')
      self.informed_from = :devpost
    elsif aurl.host.include?('eventbrite')
      self.informed_from = :eventbrite
    elsif aurl.host.include?('itch.io/jams')
      self.informed_from = :itchio
    end
  end

  def rebuild_correct_event
    aurl = Addressable::URI.parse(self.url)
    if self.connpass?
      connpass_event_id_string = aurl.path.split('/').last
      if connpass_event_id_string.present?
        events_response = ConnpassOperation.find_event(event_id: connpass_event_id_string)
        res_event = (events_response['events'] || []).first
        return false if res_event.blank?
        ConnpassOperation.setup_event_info(event: self, api_response_hash: res_event)
      end
    elsif self.eventbrite?
      eventbrite_last_string = aurl.path.split('/').last.to_s
      eventbrite_event_id_string = eventbrite_last_string.split('-').last
      if eventbrite_event_id_string.present?
        event_response = EventbriteOperation.find_event(event_id: eventbrite_event_id_string)
        return false if event_response.blank?
        EventbriteOperation.setup_event_info(event: self, api_response_hash: event_response)
      end
    elsif self.doorkeeper?
      doorkeeper_last_string = aurl.path.split('/').last.to_s
      if doorkeeper_last_string.present?
        event_response = DoorkeeperOperation.find_event(event_id: doorkeeper_last_string)
        return false if event_response.blank?
        DoorkeeperOperation.setup_event_info(event: self, api_response_hash: event_response['event'])
      end
    elsif self.itchio?
      event_detail_dom = RequestParser.request_and_parse_html(url: aurl.to_s, options: { follow_redirect: true })
      return false if event_detail_dom.css('.date_format').text.blank?
      ItchIoOperation.setup_event_info(event: self, event_detail_dom: event_detail_dom)
    end
    return true
  end

  def build_from_website
    response =
      RequestParser.request_and_response(
        url: self.url,
        header: {
          'Content-Type' => 'text/html; charset=UTF-8',
        },
        options: {
          customize_force_redirect: true,
          timeout_second: 30,
        },
      )
    dom = nil
    begin
      return false if response.try(:body).blank?
    rescue ArgumentError => e
      Rails.logger.warn((["error: #{e.message}"] + e.backtrace).join("\n"))
      return false
    end
    body_text = response.try(:body)
    body_text.force_encoding('UTF-8')
    text = body_text.scrub('?')
    dom = Nokogiri::HTML.parse(text)
    return false if dom.blank?
    return false if dom.text.blank?
    first_head_dom = dom.css('head').first
    return false if first_head_dom.try(:text).blank?

    # Titleとdescriptionはなんかそれらしいものを抜き取って入れておく
    first_head_dom
      .css('meta')
      .each do |meta_dom|
        dom_attrs = OpenStruct.new(meta_dom.to_h)

        # 記事サイトはハッカソン告知サイトでは無いので取り除く
        if dom_attrs.property.to_s == 'og:type' &&
             (dom_attrs.content.to_s.downcase == 'article' || dom_attrs.content.to_s.downcase == 'video')
          return false
        end

        if self.title.blank?
          if dom_attrs.property.to_s.include?('title') || dom_attrs.name.to_s.include?('title') ||
               dom_attrs.itemprop.to_s.include?('title')
            self.title = dom_attrs.content.to_s.strip.truncate(140)
          end
        end
      end
    self.title = dom.try(:title).to_s.strip.truncate(140) if self.title.blank?
    body_dom = dom.css('body').first
    return false if body_dom.blank?

    request_uri = response.header.request_uri

    # query(?以降)は全て空っぽにしておく
    request_uri.query_values = nil

    # fragment(#以降)は全て空っぽにしておく
    request_uri.fragment = nil

    # 最終的に飛んだURLになるように上書きをする
    self.url = request_uri.to_s
    sanitized_body_html = Sanitizer.basic_sanitize(body_dom.to_html)
    sanitized_body_text = Sanitizer.basic_sanitize(body_dom.text)

    delete_reg_exp =
      Regexp.new(
        [
          '(',
          [
            Sanitizer::RegexpParts::HTML_COMMENT,
            Sanitizer::RegexpParts::HTML_SCRIPT_TAG,
            Sanitizer::RegexpParts::HTML_HEADER_TAG,
            Sanitizer::RegexpParts::HTML_FOOTER_TAG,
            Sanitizer::RegexpParts::HTML_STYLE_TAG,
            Sanitizer::RegexpParts::HTML_IFRAME_TAG,
            Sanitizer::RegexpParts::HTML_ARTICLE_TAG,
          ].join(')|('),
          ')',
        ].join(''),
      )
    sanitized_main_content_html = sanitized_body_html.gsub(delete_reg_exp, '')
    description_text = Nokogiri::HTML.parse(sanitized_main_content_html).text
    self.description = description_text.split(Sanitizer.empty_words_regexp).map(&:strip).select(&:present?).join("\n")
    match_address = Sanitizer.japan_address_regexp.match(sanitized_body_text)

    if match_address.present?
      self.address = match_address
      self.place = self.address
    else
      # オンラインの場合を検索する
      scaned_online = sanitized_main_content_html.downcase.scan(Sanitizer.online_regexp)
      self.place = 'online' if scaned_online.present?
    end

    current_time = Time.current
    candidate_dates = Sanitizer.scan_candidate_datetime(sanitized_main_content_html)

    # 前後一年以内の日時が候補
    # 時間が早い順にsortした
    filtered_dates =
      candidate_dates
        .select { |candidate_date| ((current_time.year - 1)..(current_time.year + 1)).cover?(candidate_date.year) }
        .uniq
        .sort

    candidate_times = Sanitizer.scan_candidate_time(sanitized_main_content_html)
    filtered_times =
      candidate_times.select do |candidate_time|
        0 <= candidate_time[0].to_i && candidate_time[0].to_i < 30 && 0 <= candidate_time[1].to_i &&
          candidate_time[1].to_i < 60 && 0 <= candidate_time[2].to_i && candidate_time[2] < 60
      end.uniq
    filtered_times.sort_by! { |time| time[0].to_i * 10_000 + time[1].to_i * 100 + time[2].to_i }
    start_time_array = filtered_times.first || []
    end_time_array = filtered_times.last || []
    start_at_datetime = filtered_dates.first
    end_at_datetime = filtered_dates.last

    self.started_at =
      start_at_datetime.try(
        :advance,
        { hours: start_time_array[0].to_i, minutes: start_time_array[1].to_i, secounds: start_time_array[2].to_i },
      )
    if end_at_datetime.present?
      self.ended_at =
        end_at_datetime.try(
          :advance,
          { hours: end_time_array[0].to_i, minutes: end_time_array[1].to_i, secounds: end_time_array[2].to_i },
        )
    end

    if self.started_at.present?
      # 解析した結果、始まりと終わりが同時刻になってしまったのなら、その日の終わりを終了時刻とする
      if self.started_at == self.ended_at
        self.ended_at = self.started_at.try(:end_of_day)
        # ended_atがなければとりあえず開始日の2日後に終了すると仮定する
      elsif self.ended_at.blank?
        self.ended_at = (self.started_at + 2.day).end_of_day
      end
    end
    self.check_score_rate = 1.to_f
    return true
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
    words += [image_html, ''] if image_html.present?

    words +=
      [self.started_at.strftime('%Y年%m月%d日'), self.place, "[#{self.address}](#{self.generate_google_map_url})"]
    words << "定員#{self.limit_number}人" if self.limit_number.present?

    if self.attend_number >= 0
      if self.ended_at < Time.current
        words << "#{self.attend_number}人が参加しました"
      else
        words << "#{Time.now.strftime('%Y年%m月%d日 %H:%M')}現在 #{self.attend_number}人参加中"

        if self.limit_number.present?
          remain_number = self.limit_number - self.attend_number
          if remain_number > 0
            words << "<font color=\"#FF0000;\">あと残り#{remain_number}人</font> 参加可能"
          else
            words <<
              "今だと補欠登録されると思います。<font color=\"#FF0000\">(#{self.substitute_number}人が補欠登録中)</font>"
          end
        end
      end
    end
    return words.join("\n")
  end

  def og_image_html
    # すでにイベントが閉鎖しているのだからその後の処理をやらないようにしてみる
    return '' unless self.active?
    image_url = self.get_og_image_url
    if image_url.present?
      size_text =
        AdjustImage.calc_resize_text(
          width: self.og_image_info['width'].to_i,
          height: self.og_image_info['height'].to_i,
          max_length: 300,
        )
      resize_width, resize_height = size_text.split('x')
      return(
        ActionController::Base.helpers.image_tag(
          image_url,
          { width: resize_width, height: resize_height, alt: self.title },
        )
      )
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
        }\"></iframe>",
      )
    )
  end

  def get_og_image_url
    return self.og_image_url if self.og_image_url.present?

    # activeじゃないものは取得できないはずなのでリクエストを飛ばす前に返しちゃう
    return nil unless self.active?
    dom = RequestParser.request_and_parse_html(url: self.url, options: { follow_redirect: true })
    og_image_dom = dom.css("meta[@property = 'og:image']").first
    if og_image_dom.present?
      image_url = og_image_dom['content'].to_s
      self.og_image_url = image_url.to_s
      self.save
      return self.og_image_url
    end
    return nil
  end

  def short_url
    convert_to_short_url! if shortener_url.blank?
    return self.shortener_url
  end

  # {年}{開始月}{終了月}になるように番号を形成する
  def season_date_number
    number = self.started_at.year * 10_000
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

  def url_active?
    response = RequestParser.request_and_response(url: self.url, method: :head, options: {follow_redirect: true})
    return response.present? && response.status < 400
  end

  def zaoraru!
    return false unless self.closed?
    return false unless self.url_active?
    self.update!(state: :active)
    return true
  end

  def get_short_url
    result =
      RequestParser.request_and_parse_json(
        url: BITLY_SHORTEN_API_URL,
        method: :post,
        header: {
          'Authorization' => "Bearer #{ENV.fetch('BITLY_ACCESS_TOKEN', '')}",
          'Content-Type' => 'application/json',
        },
        body: { long_url: self.url }.to_json,
        options: {
          follow_redirect: true,
        },
      )
    if result['id'].present?
      return 'https://' + result['id']
    else
      return nil
    end
  end
end
