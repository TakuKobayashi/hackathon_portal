module DoorkeeperOperation
  DOORKEEPER_URL = 'https://api.doorkeeper.jp/events'

  def self.find_event(keywords:, page: 1)
    return(
      RequestParser.request_and_parse_json(
        url: DOORKEEPER_URL,
        params: { q: keywords.join('|'), page: page },
        header: { 'Authorization' => ['Bearer', ENV.fetch('DOORKEEPER_API_KEY', '')].join(' ') },
      )
    )
  end

  def self.import_events_from_keywords!(keywords:)
    page = 1
    begin
      events_response = self.find_event(keywords: keywords, page: page)
      current_events =
        Event.doorkeeper.where(event_id: events_response.map { |res| res['event']['id'] }.compact).index_by(&:event_id)
      events_response.each do |res|
        Event.transaction do
          event = res['event']
          if current_events[event['id'].to_s].present?
            doorkeeper_event = current_events[event['id'].to_s]
          else
            doorkeeper_event = Event.new(event_id: event['id'].to_s)
          end
          doorkeeper_event.merge_event_attributes(
            attrs: {
              state: :active,
              informed_from: :doorkeeper,
              title: event['title'].to_s,
              url: event['public_url'].to_s,
              description: Sanitizer.basic_sanitize(event['description'].to_s),
              limit_number: event['ticket_limit'],
              address: event['address'],
              place: event['venue_name'].to_s,
              lat: event['lat'],
              lon: event['long'],
              cost: 0,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_id: event['group'],
              attend_number: event['participants'],
              substitute_number: event['waitlisted'],
              started_at: event['starts_at'],
              ended_at: event['ends_at'],
            },
          )
          doorkeeper_event.save!
          doorkeeper_event.import_hashtags!(hashtag_strings: doorkeeper_event.search_hashtags)
        end
      end
      page += 1
    end while events_response.present?
  end
end
