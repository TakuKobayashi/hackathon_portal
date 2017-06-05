# == Schema Information
#
# Table name: events
#
#  id            :integer          not null, primary key
#  event_id      :string(255)
#  type          :string(255)
#  keyword       :string(255)      not null
#  title         :string(255)      not null
#  url           :string(255)      not null
#  description   :string(255)      not null
#  started_at    :datetime         not null
#  ended_at      :datetime         not null
#  limit         :integer          default(0), not null
#  address       :string(255)      not null
#  place         :string(255)      not null
#  lat           :float(24)
#  lon           :float(24)
#  cost          :integer          default(0), not null
#  max_prize     :integer          default(0), not null
#  currency_unit :string(255)      default("円"), not null
#  owner_id      :string(255)
#  owner_name    :string(255)
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type)
#  index_events_on_keyword                  (keyword)
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

class Connpass < Event
  CONNPASS_URL = "https://connpass.com/api/v1/event/".freeze

  def self.find_event(keyword)
    require "net/http"
    require "time"

    uri = URI.parse "#{CONNPASS_URL}?keyword=#{URI.escape keyword}"
    JSON.parse(Net::HTTP.get uri)["events"].map { |event|
      {
        event_url: event["event_url"],
        title: event["title"],
        address: event["address"],
        place: event["place"],
        started_at: Time.parse(event["started_at"]),
      }
    }
  end
end
