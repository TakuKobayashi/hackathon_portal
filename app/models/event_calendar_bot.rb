# == Schema Information
#
# Table name: event_calendar_bots
#
#  id                    :integer          not null, primary key
#  from_type             :string(255)      not null
#  from_id               :integer          not null
#  calender_id           :string(255)      not null
#  calender_event_id     :string(255)      not null
#  duplicate_event_count :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_event_calendar_bots_on_calender_event_id      (calender_event_id)
#  index_event_calendar_bots_on_from_type_and_from_id  (from_type,from_id)
#

require 'google/apis/calendar_v3'

class EventCalendarBot < ApplicationRecord
  POST_CALENDER_NAME = "hackathon_event"

  def self.search_post_calender
    service = self.google_calender_client
  end

  def self.google_calender_client
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = GoogleOauth2Client.oauth2_client
    return service
  end
end
