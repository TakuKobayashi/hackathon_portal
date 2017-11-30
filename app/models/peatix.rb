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
  PEATIX_SEARCH_URL = PEATIX_ROOT_URL + "/search"

  def self.find_event(keywords:, start: 1)
    event_dom = ApplicationRecord.request_and_parse_html(url: PEATIX_SEARCH_URL, params: {q: keywords.join(" "), country: "JP", p: 1, size: 10})
    self.import_events!(event_dom)
    return event_dom
  end

  def self.import_events!(event_dom)
    peatix_events = []
    update_columns = Peatix.column_names - ["id", "type", "shortener_url", "event_id", "created_at"]
    event_list_dom = event_dom.css(".event-list")
    event_list_dom.css("a").each do |adom|
      next if adom["href"].blank?
      url = Addressable::URI.parse(adom["href"].to_s)
      next if url.scheme.blank? || !url.to_s.include?(PEATIX_ROOT_URL)
      location_str = Charwidth.normalize(adom.css(".event-thumb_location").text)
      address_str = Sanitizer.scan_japan_address(location_str).flatten.map(&:strip).join
      place_str = location_str.gsub(address_str, "").split(" ").reject{|l| l.strip.blank? || l.include?("会場") || l.include?("〒") }.join(" ")
      event_detail_dom = ApplicationRecord.request_and_parse_html(url: url.origin.to_s + url.path.to_s)
      owner_name_arr = Charwidth.normalize(adom.css("span.event-thumb_organizer").text).split(" ")
      owner_url = event_detail_dom.css(".pod-thumb_link").map{|a| a["href"]}.compact.first
      peatix_event = Peatix.new(
        event_id: url.path.to_s.split("/").last.to_s,
        title: adom.css("h3").text.to_s.strip,
        url: url.origin.to_s + url.path.to_s,
        description: Sanitizer.basic_sanitize(event_detail_dom.css("#field-event-description").css("select").to_html),
        address: event_detail_dom.css("#field-event-address").text.strip,
        place: place_str,
        cost: 0,
        max_prize: 0,
        currency_unit: "円",
        owner_id: owner_url.to_s.split("/").last,
        attend_number: event_detail_dom.css("a").detect{|a| a[:href].to_s.include?("/attendees") }.try(:text).to_i,
        owner_name: owner_name_arr[1..owner_name_arr.size].join(" ")
      )
      datetime_dom = adom.css("time").detect{|time_dom| time_dom["datetime"].present? }
      if datetime_dom.present?
        peatix_event.started_at = DateTime.parse(datetime_dom["datetime"].to_s)
      end
      peatix_events << peatix_event
    end
    Peatix.import!(peatix_events, on_duplicate_key_update: update_columns)
  end
end
