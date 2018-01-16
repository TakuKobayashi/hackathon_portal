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

class Peatix < Event
  PEATIX_ROOT_URL = "http://peatix.com"
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + "/search/events"

  PAGE_PER = 10

  def self.find_event(keywords:, page: 1)
    return RequestParser.request_and_parse_json(url: PEATIX_SEARCH_URL, params: {q: keywords.join(" "), country: "JP", p: page, size: PAGE_PER}, header: {"X-Requested-With" => "XMLHttpRequest"}, options: {:follow_redirect => true})
  end

  def self.import_events!
    peatix_events = []
    results_available = 0
    page = 1
    update_columns = Peatix.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    begin
      events_response = Peatix.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], page: page)
      json_data = events_response["json_data"]
      page += 1
      peatix_events = []
      json_data["events"].each do |res|
        tracking_url = Addressable::URI.parse(res["tracking_url")
        lat, lng = res["latlng"].to_s.split(",")
        peatix_event = Peatix.new(
          event_id: res["id"].to_s,
#          hash_tag: res["hash_tag"],
          title: res["name"].to_s,
          url: tracking_url.origin.to_s + tracking_url.path.to_s,
#          description: Sanitizer.basic_sanitize(res["description"].to_s),
#          limit_number: res["limit"],
          address: res["address"].to_s,
          place: res["venue_name"].to_s,
          lat: lat,
          lon: lng,
          cost: 0,
          max_prize: 0,
          currency_unit: "円",
          owner_id: res["organizer"]["id"],
          owner_nickname: res["organizer"]["name"],
          owner_name: res["organizer"]["name"],
#          attend_number: res["accepted"],
#          substitute_number: res["waiting"]
        )
        peatix_event.started_at = DateTime.parse(res["datetime"])
        peatix_events << peatix_event
      end

      Peatix.import!(peatix_events, on_duplicate_key_update: update_columns)
    end while json_data["events"].size < PAGE_PER
  end
end
