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
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

class Atnd < Event
  ATND_API_URL = "http://api.atnd.org/events/"
  ATND_EVENTPAGE_URL = "https://atnd.org/events/"

  def self.find_event(keywords:, start: 1)
    http_client = HTTPClient.new
    response = http_client.get(ATND_API_URL, {keyword_or: keywords, count: 100, start: start, format: :json}, {})
    return JSON.parse(response.body)
  end

  def self.import_events!
    extra = ExtraInfo.read_extra_info
    last_update_event_id = extra[Atnd.to_s].to_s
    stop_flg = false

    results_available = 0
    start = 1
    update_columns = Atnd.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    begin
      events_response = Atnd.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], start: start)
      start += events_response["results_returned"]
      atnd_events = []
      events_response["events"].each do |res|
        event = res["event"]
        if event["event_id"].to_s == last_update_event_id
          stop_flg = true
          break
        end
        atnd_event = Atnd.new(
          event_id: event["event_id"].to_s,
          title: event["title"].to_s,
          url: ATND_EVENTPAGE_URL + event["event_id"].to_s,
          description: ApplicationRecord.basic_sanitize(event["description"].to_s),
          limit_number: event["limit"],
          address: event["address"].to_s,
          place: event["place"].to_s,
          lat: event["lat"],
          lon: event["lon"],
          cost: 0,
          max_prize: 0,
          currency_unit: "円",
          owner_id: event["owner_id"],
          owner_nickname: event["owner_nickname"],
          attend_number: event["accepted"],
          substitute_number: event["waiting"]
        )
        atnd_event.started_at = DateTime.parse(event["started_at"])
        atnd_event.ended_at = DateTime.parse(event["ended_at"]) if event["ended_at"].present?
        atnd_events << atnd_event
        extra[Atnd.to_s] = event["event_id"].to_s
      end

      Atnd.import!(atnd_events, on_duplicate_key_update: update_columns)
    end while atnd_events.present? && !stop_flg
    ExtraInfo.update(extra)
  end
end
