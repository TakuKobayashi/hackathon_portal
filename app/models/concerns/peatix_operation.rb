module PeatixOperation
  PEATIX_ROOT_URL = 'http://peatix.com'
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + '/search/events'

  PAGE_PER = 10

  def self.find_event(keyword:, page: 1)
    return(
      RequestParser.request_and_parse_json(
        url: PEATIX_SEARCH_URL,
        params: {
          q: keyword,
          country: 'JP',
          p: page,
          size: PAGE_PER,
        },
        header: {
          'accept' => 'application/json',
          'X-Requested-With' => 'XMLHttpRequest',
        },
        options: {
          follow_redirect: true,
        },
      )
    )
  end

  def self.setup_event_info(event:, api_response_hash:)
    lat, lng = api_response_hash['latlng'].to_s.split(',')
    ops = OpenStruct.new
    dom = RequestParser.request_and_parse_html(url: event.url, options: { follow_redirect: true })
    ops.description = Sanitizer.basic_sanitize(dom.css('#field-event-description').to_html)
    end_time_string = dom.css('#field-event-datetime').css('strong').last.try(:text).to_s
    price_dom = dom.css("meta[@itemprop = 'price']").min_by { |price_dom| price_dom['content'].to_i }
    if price_dom.present?
      ops.cost = price_dom['content'].to_i
    else
      ops.cost = 0
    end
    ops.started_at = api_response_hash['datetime'].to_s
    parsed_started_at = DateTime.parse(ops.started_at.to_s)
    end_datetime = (parsed_started_at + (api_response_hash['days'].to_i - 1).day).beginning_of_day
    if end_time_string.present?
      end_time = DateTime.parse(end_time_string)
      end_datetime = end_datetime + end_time.hour.hours + end_time.minute.minutes
    else
      end_datetime = end_datetime.tomorrow
    end
    ops.ended_at = end_datetime
    event.merge_event_attributes(
      attrs: {
        state: :active,
        informed_from: :peatix,
        event_id: api_response_hash['id'].to_s,
        title: api_response_hash['name'].to_s,
        description: ops.description.to_s,
        address: api_response_hash['address'],
        place: api_response_hash['venue_name'].to_s,
        lat: lat,
        lon: lng,
        cost: ops.cost,
        attend_number: -1,
        max_prize: 0,
        currency_unit: 'JPY',
        owner_id: api_response_hash['organizer']['rawId'],
        owner_nickname: api_response_hash['organizer']['nickname'],
        owner_name: api_response_hash['pod']['name'],
        started_at: ops.started_at.to_s,
        ended_at: ops.ended_at.to_s,
      },
    )
    event.og_image_url = api_response_hash['cover'].to_s
    return event
  end

  def self.import_events_from_keywords!(keywords:)
=begin
    keywords.each do |keyword|
      page = 1
      begin
        events_response = self.find_event(keyword: keyword, page: page)
        json_data = events_response['json_data'] || { 'events' => [] }
        page += 1
        urls =
          json_data['events']
            .map do |res|
              tracking_url = Addressable::URI.parse(res['tracking_url'])
              tracking_url.origin.to_s + tracking_url.path.to_s
            end
            .compact
        current_url_events = Event.where(url: urls).includes(:event_detail).index_by(&:url)
        json_data['events'].each do |res|
          tracking_url = Addressable::URI.parse(res['tracking_url'])
          event_url = tracking_url.origin.to_s + tracking_url.path.to_s
          Event.transaction do
            if current_url_events[event_url].present?
              peatix_event = current_url_events[event_url]
            else
              peatix_event = Event.new(url: event_url)
            end
            peatix_event = self.setup_event_info(event: peatix_event, api_response_hash: res)
            peatix_event.save!
            peatix_event.import_hashtags!(hashtag_strings: peatix_event.search_hashtags)
          end
          sleep 1
        end
      end while json_data['events'].present?
    end
=end
  end
end
