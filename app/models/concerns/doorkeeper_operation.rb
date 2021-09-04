module DoorkeeperOperation
  DOORKEEPER_URL = 'https://api.doorkeeper.jp/events'

  def self.search_events(keywords:, page: 1)
    return(
      RequestParser.request_and_parse_json(
        url: DOORKEEPER_URL,
        params: {
          q: keywords.join('|'),
          page: page,
        },
        header: {
          'Authorization' => ['Bearer', ENV.fetch('DOORKEEPER_API_KEY', '')].join(' '),
        },
      )
    )
  end

  def self.find_event(event_id:)
    return(
      RequestParser.request_and_parse_json(
        url: DOORKEEPER_URL + "/" + event_id,
        header: {
          'Authorization' => ['Bearer', ENV.fetch('DOORKEEPER_API_KEY', '')].join(' '),
        },
      )
    )
  end

  def self.setup_event_info(event:, api_response_hash:)
    event.merge_event_attributes(
      attrs: {
        state: :active,
        informed_from: :doorkeeper,
        event_id: api_response_hash['id'].to_s,
        title: api_response_hash['title'].to_s,
        description: Sanitizer.basic_sanitize(api_response_hash['description'].to_s),
        limit_number: api_response_hash['ticket_limit'],
        address: api_response_hash['address'],
        place: api_response_hash['venue_name'].to_s,
        lat: api_response_hash['lat'],
        lon: api_response_hash['long'],
        cost: 0,
        max_prize: 0,
        currency_unit: 'JPY',
        owner_id: api_response_hash['group'],
        attend_number: api_response_hash['participants'],
        substitute_number: api_response_hash['waitlisted'],
        started_at: api_response_hash['starts_at'],
        ended_at: api_response_hash['ends_at'],
      },
    )
    return event
  end

  def self.import_events_from_keywords!(keywords:)
    page = 1
    begin
      events_response = self.search_events(keywords: keywords, page: page)
      current_url_events =
        Event.where(url: events_response.map { |res| res['event']['public_url'] }.compact).index_by(&:url)
      events_response.each do |res|
        Event.transaction do
          event = res['event']
          if current_url_events[event['public_url'].to_s].present?
            doorkeeper_event = current_url_events[event['public_url'].to_s]
          else
            doorkeeper_event = Event.new(url: event['public_url'].to_s)
          end
          doorkeeper_event = self.setup_event_info(event: doorkeeper_event, api_response_hash: event)
          doorkeeper_event.save!
          doorkeeper_event.import_hashtags!(hashtag_strings: doorkeeper_event.search_hashtags)
        end
      end
      page += 1
    end while events_response.present?
  end
end
