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

class Doorkeeper < Event
  DOORKEEPER_URL = "https://api.doorkeeper.jp/events"

  def self.find_event(keywords:, page: 1)
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http_client.get(DOORKEEPER_URL, {q: keywords.join("|"), page: page}, {})
    return JSON.parse(response.body)
  end

  def self.import_events!
    extra = ExtraInfo.read_extra_info
    last_update_event_id = extra[Doorkeeper.to_s].to_s
    stop_flg = false

    page = 1
    update_columns = Doorkeeper.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    begin
      events_response = Doorkeeper.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], page: page)
      doorkeeper_events = []
      events_response.each do |res|
        event = res["event"]
        if event["id"].to_s == last_update_event_id
          stop_flg = true
          break
        end
        doorkeeper_event = Doorkeeper.new(
          event_id: event["id"].to_s,
          title: event["title"].to_s,
          url: event["public_url"].to_s,
          description: Sanitizer.basic_sanitize(event["description"].to_s),
          limit_number: event["ticket_limit"],
          address: event["address"].to_s,
          place: event["venue_name"].to_s,
          lat: event["lat"],
          lon: event["long"],
          cost: 0,
          max_prize: 0,
          currency_unit: "円",
          owner_id: event["group"],
          attend_number: event["participants"],
          substitute_number: event["waitlisted"]
        )
        doorkeeper_event.started_at = DateTime.parse(event["starts_at"])
        doorkeeper_event.ended_at = DateTime.parse(event["ends_at"]) if event["ends_at"].present?
        doorkeeper_events << doorkeeper_event
        extra[Doorkeeper.to_s] = event["id"].to_s
      end
      Doorkeeper.import!(doorkeeper_events)
      page += 1
    end while events_response.present? && !stop_flg
    ExtraInfo.update(extra)
  end
end
