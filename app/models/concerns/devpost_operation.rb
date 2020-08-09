module DevpostOperation
  DEVPOST_HACKATHONS_URL = 'https://devpost.com/hackathons'

  def self.imoport_hackathon_events!
    page = 1
    events = []
    begin
      doc = RequestParser.request_and_parse_html(url: DEVPOST_HACKATHONS_URL, params: { page: page })
      url_event_options = {}
      doc.css("article").each do |article_dom|
        content_list = article_dom.css("li")
        a_tag = article_dom.css("a").first || {}
        a_url = Addressable::URI.parse(a_tag[:href].to_s)
        price_text = content_list[0].try(:css, ".value").try(:text).to_s
        price_number = price_text.slice(1, price_text.size).split(",").join.to_i
        attend_text = content_list[2].try(:css, ".value").try(:text).to_s
        url_event_options[a_url.origin + a_url.path] = {
          "max_prize" => price_number,
          "currency_unit" => price_text[0],
          "attend_number" => attend_text.to_i
        }
      end.flatten
      url_devpost_events = Event.where(url: url_event_options.keys).index_by(&:url)
      url_event_options.keys.each do |event_url|
        next if url_devpost_events[event_url].present?
        devpost_event = self.analyze_and_build_event(url: event_url, options: url_event_options[event_url])
        devpost_event.save!
      end
      page += 1
      sleep 1
    end while events.present?
  end

  def self.analyze_and_build_event(url:, options: {})
    detail_page = RequestParser.request_and_parse_html(url: url)
    event_json = JSON.parse(detail_page.css("#challenge-json-ld").text.strip)
    event_struct = OpenStruct.new(event_json)
    devpost_event = Event.new(
      url: event_struct.url.to_s,
      informed_from: :devpost,
      title: event_struct.name.to_s,
      description: event_struct.description.to_s,
      state: :active,
      started_at: Time.parse(event_struct.startDate),
      ended_at: Time.parse(event_struct.endDate),
    )
    organizer_struct = OpenStruct.new(event_struct.organizer || {})
    location_struct = OpenStruct.new(event_struct.location || {})
    address_struct = OpenStruct.new(location_struct.address || {})
    if address_struct.name.downcase == 'online'
      devpost_event.place = address_struct.name
    else
      devpost_event.address = address_struct.streetAddress
      devpost_event.place = detail_page.css(".location").css("p").first.try(:text) || address_struct.streetAddress
      devpost_event.place = devpost_event.place.to_s.strip
    end
    devpost_event.merge_event_attributes(
      attrs: {
        attend_number: 0,
        max_prize: 0,
        currency_unit: 'JPY',
        owner_name: organizer.name,
      }.merge(options),
    )
    return devpost_event
  end
end
