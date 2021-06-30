module PeatixOperation
  PEATIX_ROOT_URL = 'http://peatix.com'
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + '/search/events'

  PAGE_PER = 10

  def self.find_event(keywords:, page: 1)
    return(
      RequestParser.request_and_parse_json(
        url: PEATIX_SEARCH_URL,
        params: { q: keywords.join(' '), country: 'JP', p: page, size: PAGE_PER },
        header: { "accept" => "application/json", 'X-Requested-With' => 'XMLHttpRequest' },
        options: { follow_redirect: true },
      )
    )
  end

  def self.import_events_from_keywords!(keywords:)
    page = 1
    begin
      events_response = self.find_event(keywords: keywords, page: page)
      json_data = events_response['json_data'] || { 'events' => [] }
      page += 1
      urls = json_data['events'].map do |res|
        tracking_url = Addressable::URI.parse(res['tracking_url'])
        tracking_url.origin.to_s + tracking_url.path.to_s
      end.compact
      current_url_events =
        Event.peatix.where(url: urls).index_by(&:url)
      json_data['events'].each do |res|
        tracking_url = Addressable::URI.parse(res['tracking_url'])
        event_url = tracking_url.origin.to_s + tracking_url.path.to_s
        Event.transaction do
          lat, lng = res['latlng'].to_s.split(',')
          if current_url_events[event_url].present?
            peatix_event = current_url_events[event_url]
          else
            peatix_event = Event.new(url: event_url)
          end
          peatix_event.merge_event_attributes(
            attrs: {
              state: :active,
              informed_from: :peatix,
              event_id: res['id'].to_s,
              title: res['name'].to_s,
              address: res['address'],
              place: res['venue_name'].to_s,
              lat: lat,
              lon: lng,
              attend_number: -1,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_id: res['organizer']['id'],
              owner_nickname: res['organizer']['name'],
              owner_name: res['organizer']['name'],
              started_at: res['datetime'].to_s,
            },
          )
          dom = RequestParser.request_and_parse_html(url: peatix_event.url, options: { follow_redirect: true })
          peatix_event.description = Sanitizer.basic_sanitize(dom.css('#field-event-description').to_html)
          price_dom = dom.css("meta[@itemprop = 'price']").min_by { |price_dom| price_dom['content'].to_i }
          if price_dom.present?
            peatix_event.cost = price_dom['content'].to_i
          else
            peatix_event.cost = 0
          end
          peatix_event.save!
          peatix_event.import_hashtags!(hashtag_strings: peatix_event.search_hashtags)
        end
        sleep 1
      end
    end while json_data['events'].present?
  end
end
