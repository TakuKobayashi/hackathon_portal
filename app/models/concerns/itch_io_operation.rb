module ItchIoOperation
  ITCH_IO_JAMS_URL = 'https://itch.io/jams'

  def self.import_events_from_keywords!(keywords:)
    self.imoport_gamejam_events!
  end

  def self.setup_event_info(event:, event_detail_dom:)
    start_datetime, end_datetime = event_detail_dom.css('.date_format').map { |date| DateTime.parse(date.text) }
    aurl = Addressable::URI.parse(event.url)
    event.merge_event_attributes(
      attrs: {
        state: :active,
        informed_from: :itchio,
        event_id: aurl.path.split('/').last.to_s,
        title: event_detail_dom.css('.jam_title_header').text,
        description: Sanitizer.basic_sanitize(event_detail_dom.css('.jam_content').children.to_html),
        limit_number: nil,
        address: nil,
        place: 'Online',
        cost: 0,
        max_prize: 0,
        currency_unit: 'JPY',
        attend_number: event_detail_dom.css('.stat_value').text.to_i,
        started_at: start_datetime.utc,
        ended_at: end_datetime.utc,
      },
    )
    return event
  end

  def self.imoport_gamejam_events!
    root_uri = Addressable::URI.parse(ITCH_IO_JAMS_URL)
    page = 1
    loop do
      # https://itch.io/jams/upcoming ここから情報を取得した方が何かと都合がいい
      root_uri.path = '/jams/upcoming'
      events_dom =
        RequestParser.request_and_parse_html(
          url: root_uri.to_s,
          params: {
            page: page,
          },
          options: {
            follow_redirect: true,
          },
        )
      event_url_set = Set.new
      events_dom
        .css('.jam')
        .each do |jam_dom|
          jam_dom
            .css('.jam_top_row')
            .each do |jam_top_dom|
              event_url_path = jam_top_dom.css('a').map { |a| a[:href] }.uniq.compact.first
              if event_url_path.present?
                root_uri.path = event_url_path
                event_url_set << root_uri.to_s
              end
            end
        end
      break if event_url_set.blank?
      current_url_events = Event.where(url: event_url_set).index_by(&:url)
      event_url_set.each do |event_url|
        if current_url_events[event_url].present?
          gamejam_event = current_url_events[event_url]
        else
          gamejam_event = Event.new(url: event_url)
        end
        event_detail_dom = RequestParser.request_and_parse_html(url: event_url, options: { follow_redirect: true })
        next if event_detail_dom.title.blank?
        Event.transaction do
          hashtags =
            event_detail_dom
              .css('.jam_host_header')
              .map { |d| d.css('a').map { |a| a.text }.select { |text| text.include?('#') } }
              .flatten
          gamejam_event = self.setup_event_info(event: gamejam_event, event_detail_dom: event_detail_dom)
          gamejam_event.save!
          gamejam_event.import_hashtags!(hashtag_strings: hashtags)
        end
        sleep 1
      end
      page = page + 1
    end
  end
end
