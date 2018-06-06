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

class Meetup < Event
  MEETUP_SEARCH_URL = "https://api.meetup.com/find/upcoming_events"

  PAGE_PER = 100

  def self.find_event(keywords: [])
    return RequestParser.request_and_parse_json(url: MEETUP_SEARCH_URL, params: {key: ENV.fetch("MEETUP_API_KEY", ""), text: keywords.join("|"), sign: true, page: PAGE_PER}, options: {:follow_redirect => true})
  end

  def self.import_events!
    update_columns = Meetup.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    events_response = Meetup.find_event(keywords: Event::HACKATHON_KEYWORDS + ["はっかそん"])
    current_events = Meetup.where(event_id: events_response["events"].map{|res| res["id"]}.compact).index_by(&:event_id)
    transaction do
      events_response["events"].each do |res|
        if current_events[res["id"].to_s].present?
          meetup_event = current_events[res["id"].to_s]
        else
          meetup_event = Meetup.new(event_id: res["id"].to_s)
        end
        start_time = Time.at(res["time"].to_i / 1000)
        if res["duration"].present?
          end_time = start_time + (res["duration"] / 1000).second
        else
          end_time = start_time + 2.day
        end
        vanue_hash = res["venue"] || {}
        fee_hash = res["fee"] || {}
        group_hash = res["group"] || {}
        meetup_event.attributes = meetup_event.attributes.merge({
          title: Sanitizer.basic_sanitize(res["name"].to_s),
          url: res["link"].to_s,
          description: Sanitizer.basic_sanitize(res["description"].to_s),
          started_at: start_time,
          ended_at: end_time,
          limit_number: res["rsvp_limit"],
          address: vanue_hash["address_1"].to_s,
          place: vanue_hash["name"].to_s,
          lat: vanue_hash["lat"],
          lon: vanue_hash["lon"],
          cost: fee_hash["amount"].to_i,
          max_prize: 0,
          currency_unit: fee_hash["currency"] || "JPY",
          owner_id: group_hash["id"],
          owner_nickname: group_hash["urlname"],
          owner_name: Sanitizer.basic_sanitize(group_hash["name"].to_s),
          attend_number: res["yes_rsvp_count"] || res["attendance_count"],
          substitute_number: res["waitlist_count"]
        })
        meetup_event.set_location_data
        meetup_event.save!
        meetup_event.import_hashtags!(hashtag_strings: meetup_event.search_hashtags)
      end
    end
  end
end
