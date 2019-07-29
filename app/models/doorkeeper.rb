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

class Doorkeeper < Event
  DOORKEEPER_URL = 'https://api.doorkeeper.jp/events'

  def self.find_event(keywords:, page: 1)
    return RequestParser.request_and_parse_json(url: DOORKEEPER_URL, params: { q: keywords.join('|'), page: page })
  end

  def self.import_events!
    page = 1
    while events_response.present?
      begin
        events_response = Doorkeeper.find_event(keywords: Event::HACKATHON_KEYWORDS + %w[はっかそん], page: page)
        current_events = Doorkeeper.where(event_id: events_response.map { |res| res['event']['id'] }.compact).index_by(&:event_id)
        transaction do
          events_response.each do |res|
            event = res['event']
            if current_events[event['id'].to_s].present?
              doorkeeper_event = current_events[event['id'].to_s]
            else
              doorkeeper_event = Doorkeeper.new(event_id: event['id'].to_s)
            end
            doorkeeper_event.merge_event_attributes(
              attrs: {
                title: event['title'].to_s,
                url: event['public_url'].to_s,
                description: Sanitizer.basic_sanitize(event['description'].to_s),
                limit_number: event['ticket_limit'],
                address: event['address'].to_s,
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
                ended_at: event['ends_at']
              }
            )
            doorkeeper_event.save!
            doorkeeper_event.import_hashtags!(hashtag_strings: doorkeeper_event.search_hashtags)
          end
        end
        page += 1
      end
    end
  end
end
