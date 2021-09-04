module ConnpassOperation
  CONNPASS_URL = 'https://connpass.com/api/v1/event/'

  def self.find_event(keywords: nil, start: 1, event_id: nil)
    return(
      RequestParser.request_and_parse_json(
        url: CONNPASS_URL,
        params: {
          keyword_or: keywords,
          count: 100,
          start: start,
          order: 1,
          event_id: event_id,
        },
      )
    )
  end

  def self.setup_event_info(event:, api_response_hash:)
    event.merge_event_attributes(
      attrs: {
        state: :active,
        informed_from: :connpass,
        event_id: api_response_hash['event_id'].to_s,
        title: api_response_hash['title'].to_s,
        description: Sanitizer.basic_sanitize(api_response_hash['description'].to_s),
        limit_number: api_response_hash['limit'],
        address: api_response_hash['address'],
        place: api_response_hash['place'].to_s,
        lat: api_response_hash['lat'],
        lon: api_response_hash['lon'],
        cost: 0,
        max_prize: 0,
        currency_unit: 'JPY',
        owner_id: api_response_hash['owner_id'],
        owner_nickname: api_response_hash['owner_nickname'],
        owner_name: api_response_hash['owner_display_name'],
        attend_number: api_response_hash['accepted'],
        substitute_number: api_response_hash['waiting'],
        started_at: api_response_hash['started_at'],
        ended_at: api_response_hash['ended_at'],
      },
    )
    return event
  end

  def self.import_events_from_keywords!(keywords:)
    results_available = 0
    start = 1
    begin
      events_response = self.find_event(keywords: keywords, start: start)
      results_available = events_response['results_available'] if events_response['results_available'].present?
      start += events_response['results_returned'].to_i
      res_events = events_response['events'] || []
      current_url_events = Event.where(url: res_events.map { |res| res['event_url'] }.compact).index_by(&:url)
      res_events.each do |res|
        Event.transaction do
          if current_url_events[res['event_url'].to_s].present?
            connpass_event = current_url_events[res['event_url'].to_s]
          else
            connpass_event = Event.new(url: res['event_url'].to_s)
          end
          connpass_event = self.setup_event_info(event: connpass_event, api_response_hash: res)
          connpass_event.save!
          connpass_event.import_hashtags!(hashtag_strings: res['hash_tag'].to_s.split(/\s/))
        end
        sleep 1
      end
    end while start < results_available
  end
end
