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
#  hash_tag          :string(255)
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

class Connpass < Event
  CONNPASS_URL = "https://connpass.com/api/v1/event/"

  def self.find_event(keywords:, start: 1)
    return RequestParser.request_and_parse_json(url: CONNPASS_URL, params: {keyword_or: keywords, count: 100, start: start, order: 1})
  end

  def self.import_events!
    results_available = 0
    start = 1
    update_columns = Connpass.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    begin
      events_response = Connpass.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], start: start)
      results_available = events_response["results_available"]
      start += events_response["results_returned"]
      connpass_events = []
      events_response["events"].each do |res|
        connpass_event = Connpass.new(
          event_id: res["event_id"].to_s,
          hash_tag: res["hash_tag"],
          title: res["title"].to_s,
          url: res["event_url"].to_s,
          description: Sanitizer.basic_sanitize(res["description"].to_s),
          limit_number: res["limit"],
          address: res["address"].to_s,
          place: res["place"].to_s,
          lat: res["lat"],
          lon: res["lon"],
          cost: 0,
          max_prize: 0,
          currency_unit: "JPY",
          owner_id: res["owner_id"],
          owner_nickname: res["owner_nickname"],
          owner_name: res["owner_display_name"],
          attend_number: res["accepted"],
          substitute_number: res["waiting"]
        )
        connpass_event.started_at = DateTime.parse(res["started_at"])
        connpass_event.ended_at = DateTime.parse(res["ended_at"]) if res["ended_at"].present?
        connpass_event.set_location_data
        connpass_events << connpass_event
      end

      Connpass.import!(connpass_events, on_duplicate_key_update: update_columns)
    end while start < results_available
  end
end
