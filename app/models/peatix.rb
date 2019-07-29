# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  shortener_url     :string(255)
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime
#  limit_number      :integer
#  address           :string(255)      not null
#  place             :string(255)      not null
#  lat               :float(24)
#  lon               :float(24)
#  cost              :integer          default(0), not null
#  max_prize         :integer          default(0), not null
#  currency_unit     :string(255)      default("円"), not null
#  owner_id          :string(255)
#  owner_nickname    :string(255)
#  owner_name        :string(255)
#  attend_number     :integer          default(0), not null
#  substitute_number :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  judge_state       :integer          default("before_judge"), not null
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type)
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#  index_events_on_url                      (url)
#

class Peatix < Event
  PEATIX_ROOT_URL = 'http://peatix.com'
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + '/search/events'

  PAGE_PER = 10

  def self.find_event(keywords:, page: 1)
    return RequestParser.request_and_parse_json(
      url: PEATIX_SEARCH_URL,
      params: { q: keywords.join(' '), country: 'JP', p: page, size: PAGE_PER },
      header: { 'X-Requested-With' => 'XMLHttpRequest' },
      options: { follow_redirect: true }
    )
  end

  def self.import_events!
    page = 1
    update_columns = Peatix.column_names - %w[id type shortener_url event_id created_at]
    while json_data['events'].present?
      begin
        events_response = Peatix.find_event(keywords: Event::HACKATHON_KEYWORDS + %w[はっかそん], page: page)
        json_data = events_response['json_data']
        page += 1
        current_events = Peatix.where(event_id: json_data['events'].map { |res| res['id'] }.compact).index_by(&:event_id)
        transaction do
          json_data['events'].each do |res|
            tracking_url = Addressable::URI.parse(res['tracking_url'])
            lat, lng = res['latlng'].to_s.split(',')
            if current_events[res['id'].to_s].present?
              peatix_event = current_events[res['id'].to_s]
            else
              peatix_event = Peatix.new(event_id: res['id'].to_s)
            end
            peatix_event.merge_event_attributes(
              attrs: {
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
            sleep 1
          end
        end
      end
    end
  end
end
