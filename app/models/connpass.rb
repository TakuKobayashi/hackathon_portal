# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime         not null
#  limit_number      :integer          default(0), not null
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

class Connpass < Event
  CONNPASS_URL = "https://connpass.com/api/v1/event/"

  def self.find_event(keywords:, start: 1)
    http_client = HTTPClient.new
    response = http_client.get(CONNPASS_URL, {keyword_or: keywords, count: 100, start: start, order: 1}, {})
    return JSON.parse(response.body)
  end

  def self.import_events!
    connpass_event_last = Connpass.last
    events_response = Connpass.find_event(keywords: ["ハッカソン", "hackathon", "はっかそん"])
    connpass_events = []
    events_response["events"].each do |res|
      connpass_events << Connpass.new(
        event_id: res["event_id"].to_s,
        keyword: res["keyword"].to_s,
        title: res["title"].to_s,
        url: res["event_url"].to_s,
        description: res["description"].to_s,
        started_at: res["started_at"],
        ended_at: res["ended_at"],
        limit_number: res["limit"],
        address: res["address"].to_s,
        place: res["place"].to_s,
        lat: res["lat"],
        lon: res["lon"],
        cost: 0,
        max_prize: 0,
        currency_unit: "円",
        owner_id: res["owner_id"],
        owner_nickname: res["owner_nickname"],
        owner_name: res["owner_display_name"],
        attend_number: res["accepted"],
        substitute_number: res["waiting"]
      )
    end
    Connpass.import!(connpass_events)
  end
end
