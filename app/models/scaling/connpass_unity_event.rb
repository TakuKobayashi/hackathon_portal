# == Schema Information
#
# Table name: scaling_unity_events
#
#  id                :bigint(8)        not null, primary key
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
#  index_scaling_unity_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_scaling_unity_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_scaling_unity_events_on_title                    (title)
#

class Scaling::ConnpassUnityEvent < Scaling::UnityEvent
  CONNPASS_URL = "https://connpass.com/api/v1/event/"

  def self.find_event(keywords:, start: 1)
    return RequestParser.request_and_parse_json(url: CONNPASS_URL, params: { keyword_or: keywords, count: 100, start: start, order: 1 })
  end

  def self.import_events!
    results_available = 0
    start = 1
    begin
      events_response = self.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"], start: start)
      if events_response["results_available"].present?
        results_available = events_response["results_available"]
      end
      start += events_response["results_returned"].to_i
      res_events = events_response["events"] || []
      current_events = Scaling::ConnpassUnityEvent.where(event_id: res_events.map { |res| res["event_id"] }.compact).index_by(&:event_id)
      transaction do
        res_events.each do |res|
          if current_events[res["event_id"].to_s].present?
            connpass_event = current_events[res["event_id"].to_s]
          else
            connpass_event = Scaling::ConnpassUnityEvent.new(event_id: res["event_id"].to_s)
          end
          connpass_event.merge_event_attributes(attrs: {
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
                                                  substitute_number: res["waiting"],
                                                  started_at: res["started_at"],
                                                  ended_at: res["ended_at"],
                                                })
          connpass_event.save!
          connpass_event.import_hashtags!(hashtag_strings: res["hash_tag"].to_s.split(/\s/))
          sleep 1
        end
      end
    end while start < results_available
  end
end
