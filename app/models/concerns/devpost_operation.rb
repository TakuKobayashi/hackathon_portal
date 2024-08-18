module DevpostOperation
  DEVPOST_HACKATHONS_URL = 'https://devpost.com/hackathons'
  DEVPOST_HACKATHONS_API_URL = 'https://devpost.com/api/hackathons'
  MAX_PER_PAGE = 40

  def self.import_events_from_keywords!(keywords:)
    self.imoport_hackathon_events!
  end

  def self.imoport_hackathon_events!
    page = 1
    loop do
      response_json =
        RequestParser.request_and_parse_json(
          url: DEVPOST_HACKATHONS_API_URL,
          params: {
            page: page,
            per_page: MAX_PER_PAGE,
            "status[]" => ["upcoming", "open"],
          },
          options: {
            follow_redirect: true,
          },
        )
      hackathon_info_structs = (response_json["hackathons"] || []).map{|info| OpenStruct.new(info) }
      url_devpost_events = Event.where(url: hackathon_info_structs.map(&:url)).includes(:event_detail).index_by(&:url)
      hackathon_info_structs.each do |info|
        devpost_event = url_devpost_events[info.url]
        if devpost_event.blank?
          devpost_event = Event.new(url: info.url.to_s)
        end
        started_at_date, ended_at_date = self.split_to_start_and_end_date(date_range_string: info.submission_period_dates)
        location_strut = OpenStruct.new(info.displayed_location)
        address_string = nil
        if location_strut.location.downcase != 'online'
          address_string = location_strut.location
        end
        price_amount, currency_unit = self.split_price_and_currency_unit(prize_amount_string: info.prize_amount)
        devpost_event.merge_event_attributes(
          attrs: {
            informed_from: :devpost,
            title: info.title.to_s,
            state: :active,
            started_at: started_at_date,
            ended_at: ended_at_date,
            place: location_strut.location,
            address: address_string,
            attend_number: info.registrations_count.to_i,
            max_prize: price_amount,
            currency_unit: currency_unit,
            owner_name: info.organization_name,
          },
        )

        if devpost_event.place.downcase.match(Sanitizer.online_regexp).present? ||
             devpost_event.place.downcase.include?('japan')
          tags = (info.themes || []).map{|theme| theme["name"]}
          devpost_event.save!
          devpost_event.import_hashtags!(hashtag_strings: tags)
        end
      end
      meta_struct = OpenStruct.new(response_json["meta"] || {})
      break if (page * MAX_PER_PAGE) >= meta_struct.total_count.to_i
      page += 1
      sleep 1
    end
  end

  def self.analyze_and_build_event(url:, options: {})
    detail_page = RequestParser.request_and_parse_html(url: url)
    event_json = JSON.parse(detail_page.css('#challenge-json-ld').text.strip)
    event_struct = OpenStruct.new(event_json)
    devpost_event = Event.new(url: event_struct.url.to_s)
    organizer_struct = OpenStruct.new(event_struct.organizer || {})
    location_struct = OpenStruct.new(event_struct.location || {})
    address_struct = OpenStruct.new(location_struct.address || {})
    if address_struct.name.downcase == 'online'
      event_struct.place = address_struct.name
    else
      event_struct.address = address_struct.streetAddress
      event_struct.place = detail_page.css('.location').css('p').first.try(:text) || address_struct.streetAddress
      event_struct.place = event_struct.place.to_s.strip
    end
    devpost_event.merge_event_attributes(
      attrs: {
        informed_from: :devpost,
        title: event_struct.name.to_s,
        description: event_struct.description.to_s,
        state: :active,
        started_at: Time.parse(event_struct.startDate),
        ended_at: Time.parse(event_struct.endDate),
        place: event_struct.place,
        address: event_struct.address,
        attend_number: 0,
        max_prize: 0,
        currency_unit: 'JPY',
        owner_name: organizer_struct.name,
      }.merge(options),
    )
    return devpost_event
  end

  private
  def self.split_to_start_and_end_date(date_range_string:)
    start_date_string, another_date_string = date_range_string.split('-')
    if another_date_string.present?
      end_date_string, year_string = another_date_string.split(',')
      started_at_date = Time.parse([start_date_string.strip, year_string].join(','))
      if (end_date_string.strip =~ /^[0-9]+$/).nil?
        ended_at_date = Time.parse([end_date_string.strip, year_string].join(','))
      else
        start_month_string, start_day_string = start_date_string.strip.split(' ')
        ended_at_date = Time.parse([[start_month_string, end_date_string.strip].join(' '), year_string].join(','))
      end
    else
      start_date_string_strip, year_string = start_date_string.strip.split(',')
      started_at_date = Time.parse([start_date_string_strip, year_string].join(','))
      ended_at_date = started_at_date.end_of_day
    end
    return [started_at_date, ended_at_date]
  end

  def self.split_price_and_currency_unit(prize_amount_string:)
    price_doc = Nokogiri::HTML.parse(prize_amount_string)
    price_currency_string = price_doc.text
    price_amount = price_currency_string.gsub(/[^\d]/, "").to_i
    if price_currency_string.start_with?('$CAD')
      return [price_amount, 'CAD']
    elsif price_currency_string.start_with?('$')
      return [price_amount, 'USD']
    elsif price_currency_string.start_with?('¥')
      return [price_amount, 'JPY']
    end
    return [price_amount, 'USD']
  end
end
