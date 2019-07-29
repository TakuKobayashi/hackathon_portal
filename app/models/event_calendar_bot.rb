# == Schema Information
#
# Table name: event_calendar_bots
#
#  id                :bigint           not null, primary key
#  from_type         :string(255)      not null
#  from_id           :integer          not null
#  calender_event_id :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_event_calendar_bots_on_calender_event_id      (calender_event_id)
#  index_event_calendar_bots_on_from_type_and_from_id  (from_type,from_id)
#

require 'google/apis/calendar_v3'

class EventCalendarBot < ApplicationRecord
  belongs_to :from, polymorphic: true, required: false

  POST_CALENDER_NAME = 'ハッカソンポータル'

  def self.insert_or_update_calender!(events: [])
    service = self.google_calender_client
    target_calender_id = get_target_calender_id
    colors = service.get_color

    current_calenders = EventCalendarBot.where(from: events).index_by(&:from_id)
    event_calendars = []
    events.each do |event|
      calender_event =
        Google::Apis::CalendarV3::Event.new(
          {
            summary: event.title,
            location: [event.address, event.place].join(' '),
            description: event.description,
            start: { date_time: event.started_at.to_datetime.rfc3339 },
            source: { url: event.url, title: event.title }
          }
        )
      if event.ended_at.present?
        calender_event.end = { date_time: event.ended_at.to_datetime.rfc3339 }
      else
        calender_event.end = { date_time: event.started_at.end_of_day.to_datetime.rfc3339 }
      end
      color_id = colors.calendar.keys[Event::HACKATHON_KEYWORD_CALENDER_INDEX[event.hackathon_event_hit_keyword].to_i]
      calender_event.color_id = color_id if color_id.present?
=begin
      calender_gadget = Google::Apis::CalendarV3::Event::Gadget.new({
        title: event.title,
        link: event.url
      })
      image_url = event.get_og_image_url
      if image_url.to_s.match(/^https:\/\//).present?
        calender_gadget.icon_link = image_url
      end
      calender_event.gadget = calender_gadget.to_h
=end

      if current_calenders[event.id].present?
        current_event_calendar_bot = current_calenders[event.id]
        service.update_event(target_calender_id, current_event_calendar_bot.calender_event_id, calender_event)
        event_calendars << current_event_calendar_bot
      else
        result = service.insert_event(target_calender_id, calender_event)
        event_calendars << EventCalendarBot.create!(from: event, calender_event_id: result.id)
      end
    end

    GoogleOauth2Client.record_access_token(
      refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_CALENDER_REFRESH_TOKEN', ''), authorization: service.authorization
    )
    return event_calendars
  end

  def self.get_target_calender_id
    local_storage = ExtraInfo.read_extra_info
    if local_storage['target_post_calender_id'].present?
      return local_storage['target_post_calender_id']
    else
      service = self.google_calender_client
      calenders = service.list_calendar_lists
      target_calender = calenders.items.detect { |item| item.summary == POST_CALENDER_NAME }
      ExtraInfo.update({ 'target_post_calender_id' => target_calender.try(:id) })
      return target_calender.try(:id)
    end
  end

  def self.google_calender_client
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    return service
  end
end
