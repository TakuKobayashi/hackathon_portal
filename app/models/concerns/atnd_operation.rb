module AtndOperation
  ATND_API_URL = 'http://api.atnd.org/events/'
  ATND_EVENTPAGE_URL = 'https://atnd.org/events/'

  def self.find_event(keywords:, start: 1)
    return(
      RequestParser.request_and_parse_json(
        url: ATND_API_URL,
        params: {
          keyword_or: keywords,
          count: 100,
          start: start,
          format: :json,
        },
      )
    )
  end

  def self.import_events_from_keywords!(keywords:)
    start = 1
    begin
      events_response = self.find_event(keywords: keywords, start: start)
      start += events_response['results_returned']
      current_url_events =
        Event
          .where(url: events_response['events'].map { |res| (ATND_EVENTPAGE_URL + res['event']['event_id']).to_s })
          .index_by(&:url)
      events_response['events'].each do |res|
        Event.transaction do
          event = res['event']
          if current_url_events[event['event_id'].to_s].present?
            atnd_event = current_url_events[(ATND_EVENTPAGE_URL + event['event_id']).to_s]
          else
            atnd_event = Event.new(event_id: event['event_id'].to_s)
          end
          atnd_event.merge_event_attributes(
            attrs: {
              informed_from: :atnd,
              title: event['title'].to_s,
              url: ATND_EVENTPAGE_URL + event['event_id'].to_s,
              description: Sanitizer.basic_sanitize(event['description'].to_s),
              limit_number: event['limit'],
              address: event['address'],
              place: event['place'].to_s,
              lat: event['lat'],
              lon: event['lon'],
              cost: 0,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_id: event['owner_id'],
              owner_nickname: event['owner_nickname'],
              attend_number: event['accepted'],
              substitute_number: event['waiting'],
              started_at: event['started_at'],
              ended_at: event['ended_at'],
            },
          )
          atnd_event.save!
          dom = RequestParser.request_and_parse_html(url: atnd_event.url, options: { follow_redirect: true })
          hashtag_dom = dom.css('dl.clearfix').detect { |label| label.text.include?('ハッシュタグ') }
          if hashtag_dom.present?
            atnd_event.import_hashtags!(hashtag_strings: hashtag_dom.css('a').text.strip.split(/\s/))
          end
        end
      end
    end while events_response['events'].present?
  end
end
