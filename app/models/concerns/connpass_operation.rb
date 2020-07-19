module ConnpassOperation
  CONNPASS_URL = 'https://connpass.com/api/v1/event/'

  def self.find_event(keywords:, start: 1)
    return RequestParser.request_and_parse_json(url: CONNPASS_URL, params: { keyword_or: keywords, count: 100, start: start, order: 1 })
  end

  def self.import_events_from_keywords!(event_clazz:, keywords:)
    results_available = 0
    start = 1
    begin
      events_response = self.find_event(keywords: keywords, start: start)
      results_available = events_response['results_available'] if events_response['results_available'].present?
      start += events_response['results_returned'].to_i
      res_events = events_response['events'] || []
      current_events = event_clazz.connpass.where(event_id: res_events.map { |res| res['event_id'] }.compact).index_by(&:event_id)
      res_events.each do |res|
        event_clazz.transaction do
          if current_events[res['event_id'].to_s].present?
            connpass_event = current_events[res['event_id'].to_s]
          else
            connpass_event = event_clazz.new(event_id: res['event_id'].to_s)
          end
          connpass_event.merge_event_attributes(
            attrs: {
              informed_from: :connpass,
              title: res['title'].to_s,
              url: res['event_url'].to_s,
              description: Sanitizer.basic_sanitize(res['description'].to_s),
              limit_number: res['limit'],
              address: res['address'].to_s,
              place: res['place'].to_s,
              lat: res['lat'],
              lon: res['lon'],
              cost: 0,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_id: res['owner_id'],
              owner_nickname: res['owner_nickname'],
              owner_name: res['owner_display_name'],
              attend_number: res['accepted'],
              substitute_number: res['waiting'],
              started_at: res['started_at'],
              ended_at: res['ended_at']
            }
          )
          connpass_event.save!
          connpass_event.import_hashtags!(hashtag_strings: res['hash_tag'].to_s.split(/\s/))
        end
        sleep 1
      end
    end while start < results_available
  end
end
