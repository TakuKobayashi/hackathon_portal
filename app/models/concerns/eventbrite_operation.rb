module EventbriteOperation
  # https://www.eventbrite.com/
  # https://www.eventbrite.com/platform/api
  EVENTBRITE_API_URL = 'https://www.eventbriteapi.com/v3'
  EVENTBRITE_URL = 'https://www.eventbrite.com'

  def self.find_event(event_id:)
    return(
      RequestParser.request_and_parse_json(
        url: EVENTBRITE_API_URL + '/events/' + event_id + '/',
        header: {
          'Authorization' => ['Bearer', ENV.fetch('EVENTBRITE_API_TOKEN', '')].join(' '),
        },
        options: {
          follow_redirect: true,
        },
      )
    )
  end

  def self.load_venue(venue_id:)
    return(
      RequestParser.request_and_parse_json(
        url: EVENTBRITE_API_URL + '/venues/' + venue_id + '/',
        header: {
          'Authorization' => ['Bearer', ENV.fetch('EVENTBRITE_API_TOKEN', '')].join(' '),
        },
        options: {
          follow_redirect: true,
        },
      )
    )
  end

  def self.setup_event_info(event:, api_response_hash:)
    venue_info = OpenStruct.new
    if api_response_hash['venue_id'].present?
      venue_response_hash = self.load_venue(venue_id: api_response_hash['venue_id'])
      venue_info.lat = venue_response_hash['latitude']
      venue_info.lon = venue_response_hash['longitude']
      venue_info.place = venue_response_hash['name']
      venue_info.address = (venue_response_hash['address'] || {})['localized_address_display']
    else
      venue_info.place = 'online'
    end
    event.merge_event_attributes(
      attrs: {
        state: :active,
        informed_from: :eventbrite,
        event_id: api_response_hash['id'].to_s,
        title: (api_response_hash['name'] || {})['text'].to_s,
        description: Sanitizer.basic_sanitize((api_response_hash['description'] || {})['html'].to_s),
        limit_number: api_response_hash['capacity'],
        address: venue_info.address,
        place: venue_info.place,
        lat: venue_info.lat,
        lon: venue_info.lon,
        cost: 0,
        max_prize: 0,
        currency_unit: api_response_hash['currency'].to_s,
        owner_id: api_response_hash['organization_id'].to_s,
        attend_number: 0,
        started_at: (api_response_hash['start'] || {})['utc'].to_s,
        ended_at: (api_response_hash['end'] || {})['utc'].to_s,
      },
    )
    return event
  end

  def self.import_events_from_keywords!(keywords:)
    %w[online japan].each do |location_name|
      keywords.each do |keyword|
        page = 1
        loop do
          dom =
            RequestParser.request_and_parse_html(
              url: EventbriteOperation::EVENTBRITE_URL + '/d/' + location_name + '/' + keyword + '/',
              params: {
                page: page,
              },
              options: {
                follow_redirect: true,
              },
            )
          event_urls =
            dom
              .css('ul.search-main-content__events-list')
              .map do |wrap|
                wrap
                  .css('a')
                  .map do |a|
                    aurl = Addressable::URI.parse(a[:href])
                    aurl.query = nil
                    aurl
                  end
              end
              .flatten
              .compact
              .uniq
          break if event_urls.blank?
          current_url_events = Event.where(url: event_urls.map(&:to_s)).index_by(&:url)
          event_urls.each do |event_url|
            Event.transaction do
              if current_url_events[event_url.to_s].present?
                eventbrite_event = current_url_events[event_url.to_s]
              else
                eventbrite_event = Event.new(url: event_url.to_s)
              end
              aurl = Addressable::URI.parse(event_url)
              eventbrite_last_string = aurl.path.split('/').last.to_s
              eventbrite_event_id_string = eventbrite_last_string.split('-').last
              if eventbrite_event_id_string.present?
                event_response = EventbriteOperation.find_event(event_id: eventbrite_event_id_string)
                next if event_response.blank?
                EventbriteOperation.setup_event_info(event: eventbrite_event, api_response_hash: event_response)
                eventbrite_event.save!
              end
            end
          end
          page += 1
          sleep 1
        end
      end
    end
  end
end
