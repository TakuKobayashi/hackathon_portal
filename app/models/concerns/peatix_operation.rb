module PeatixOperation
  PEATIX_ROOT_URL = 'http://peatix.com'
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + '/search/events'

  PAGE_PER = 10

  def self.find_event(keywords:, page: 1)
    return(
      RequestParser.request_and_parse_json(
        url: PEATIX_SEARCH_URL,
        params: { q: keywords.join(' '), country: 'JP', p: page, size: PAGE_PER },
        header: { 'X-Requested-With' => 'XMLHttpRequest' },
        options: { follow_redirect: true }
      )
    )
  end

  def self.import_events_from_keywords!(event_clazz:, keywords:)
    page = 1
    update_columns = event_clazz.column_names - %w[id type shortener_url event_id created_at]
    begin
      events_response = self.find_event(keywords: keywords, page: page)
      json_data = events_response['json_data'] || { 'events' => [] }
      page += 1
      current_events = event_clazz.peatix.where(event_id: json_data['events'].map { |res| res['id'] }.compact).index_by(&:event_id)
      json_data['events'].each do |res|
        event_clazz.transaction do
          tracking_url = Addressable::URI.parse(res['tracking_url'])
          lat, lng = res['latlng'].to_s.split(',')
          if current_events[res['id'].to_s].present?
            peatix_event = current_events[res['id'].to_s]
          else
            peatix_event = event_clazz.new(event_id: res['id'].to_s)
          end
          peatix_event.merge_event_attributes(
            attrs: {
              state: :active,
              informed_from: :peatix,
              title: res['name'].to_s,
              url: tracking_url.origin.to_s + tracking_url.path.to_s,
              address: res['address'].to_s,
              place: res['venue_name'].to_s,
              lat: lat,
              lon: lng,
              attend_number: -1,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_id: res['organizer']['id'],
              owner_nickname: res['organizer']['name'],
              owner_name: res['organizer']['name'],
              started_at: res['datetime'].to_s
            }
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
