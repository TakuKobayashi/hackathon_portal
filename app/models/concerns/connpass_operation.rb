module ConnpassOperation
  CONNPASS_URL = 'https://connpass.com/api/v1/event/'
  CONNPASS_SEARCH_URL = 'https://connpass.com/search/'

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
    [keywords].flatten.each do |keyword|
      event_count = 0
      page = 1
      total_count = 1
      loop do
        response_html = RequestParser.request_and_parse_html(
          url: CONNPASS_SEARCH_URL,
          params: {
            q: keyword,
            start_from: Time.current.strftime("%Y/%m/%d"),
            page: page,
          },
        )
        total_count = response_html.css('.main_h2').text.gsub(/[^\d]/, "").to_i
        event_list_docs = response_html.css(".event_list")
        event_urls = event_list_docs.map{|doc| doc.css("a.url").first.try(:attr, 'href') }.compact
        current_url_events = Event.where(url: event_urls).includes(:event_detail).index_by(&:url)
        event_list_docs.each do |event_doc|
          event_url_doc = event_doc.css("a.url").first
          event_url = Addressable::URI.parse(event_url_doc.try(:attr, 'href').to_s)
          if current_url_events[event_url.to_s].present?
            connpass_event = current_url_events[event_url.to_s]
          else
            connpass_event = Event.new(url: event_url.to_s)
          end
          event_id = event_url.path.split('/').find_all(&:present?).last
          attend_number, limit_number = event_doc.css("span.amount").text.split('/')
          substitute_number = nil
          if limit_number.present?
            substitute_number = [attend_number.to_i - limit_number.to_i, 0].max
          end
          event_owner_doc = event_doc.css('.event_owner')
          owner_info_doc = event_owner_doc.css('a').first
          owner_nickname = owner_info_doc.try(:attr, 'href').split('/').find_all(&:present?).last
          owner_name = owner_info_doc.try(:text).to_s.strip
          detail_page_doc = RequestParser.request_and_parse_html(url: event_url.to_s)
          event_schedule_doc = detail_page_doc.css('.event_schedule_area')
          start_at_value = event_schedule_doc.css('.dtstart').css('.value-title').first.try(:attr, 'title').to_s
          ended_at_value = event_schedule_doc.css('.dtend').css('.value-title').first.try(:attr, 'title').to_s
          place_info_doc = detail_page_doc.css('.event_place_area')
          place_geo_doc = place_info_doc.css('.geo')
          connpass_event.merge_event_attributes(
            attrs: {
              state: :active,
              informed_from: :connpass,
              event_id: event_id,
              title: event_url_doc.try(:text).to_s,
              description: Sanitizer.basic_sanitize(detail_page_doc.css("#editor_area").children.to_html.strip.to_s),
              limit_number: limit_number,
              address: place_info_doc.css('.adr').css('.value-title').first.try(:attr, 'title'),
              place: place_info_doc.css(".place_name").text.strip,
              lat: place_geo_doc.css(".latitude").css(".value-title").first.try(:attr, 'title'),
              lon: place_geo_doc.css(".longitude").css(".value-title").first.try(:attr, 'title'),
              cost: 0,
              max_prize: 0,
              currency_unit: 'JPY',
              owner_nickname: owner_nickname,
              owner_name: owner_name,
              attend_number: attend_number.to_i,
              substitute_number: substitute_number,
              started_at: Time.parse(start_at_value),
              ended_at: Time.parse(ended_at_value),
            },
          )
          Event.transaction do
            connpass_event.save!
            hashtags = detail_page_doc.css(".label_hashtag").map{|hashtag_dom| hashtag_dom.css("a").map{|a_tag| a_tag.text.strip } }.flatten
            connpass_event.import_hashtags!(hashtag_strings: hashtags)
          end
          event_count += 1
          sleep 1
        end
        break if total_count <= event_count
        page += 1
        sleep 1
      end
    end
  end

  def self.import_events_from_keywords_request_api!(keywords:)
    results_available = 0
    start = 1
    begin
      events_response = self.find_event(keywords: keywords, start: start)
      results_available = events_response['results_available'] if events_response['results_available'].present?
      start += events_response['results_returned'].to_i
      res_events = events_response['events'] || []
      current_url_events =
        Event.where(url: res_events.map { |res| res['event_url'] }.compact).includes(:event_detail).index_by(&:url)
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
