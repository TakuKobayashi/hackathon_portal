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

  def self.calender_title
    return 'ハッカソンポータル'
  end

  def self.generate_google_calender_event_object(event:)
    calender_description =
      ['<h1><a href="' + event.url + '">' + event.title + '</a></h1>', event.description.to_s].join('\n')
    calender_event = Google::Apis::CalendarV3::Event.new
    calender_event.summary = event.title
    calender_event.location = [event.address, event.place].join(' ')
    calender_event.description = calender_description
    start_date_time = Google::Apis::CalendarV3::EventDateTime.new
    start_date_time.date_time = event.started_at.to_datetime.rfc3339
    calender_event.start = start_date_time
    event_source = Google::Apis::CalendarV3::Event::Source.new
    event_source.url = event.url
    event_source.title = event.title
    calender_event.source = event_source
    end_date_time = Google::Apis::CalendarV3::EventDateTime.new
    end_date_time.date_time = event.ended_at.to_datetime.rfc3339
    calender_event.end = end_date_time
    return calender_event
  end

  def self.insert_or_update_calender!(events: [], refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    service = GoogleServices.get_calender_service(refresh_token: refresh_token)
    calenders = service.list_calendar_lists
    target_calender = calenders.items.detect { |item| item.summary == self.calender_title }
    target_calender_id = target_calender.try(:id)
    colors = service.get_color

    event_calendars = []
    events.each do |event|
      calender_event = self.generate_google_calender_event_object(event: event)

      #本当は ハッカソンは1, アイディアソンは2, ゲームジャムは3, 開発合宿は4
      if event.hackathon_event?
        color_id = colors.calendar.keys[1]
      elsif event.development_camp?
        color_id = colors.calendar.keys[4]
      else
        color_id = colors.calendar.keys[5]
      end
      calender_event.color_id = color_id if color_id.present?
      calender_bot = self.find_or_initialize_by(from: event)
      begin
        if calender_bot.new_record?
          result = service.insert_event(target_calender_id, calender_event)
          calender_bot.calender_event_id = result.id
          calender_bot.save!
        else
          service.update_event(target_calender_id, calender_bot.calender_event_id, calender_event)
        end
      rescue Google::Apis::RateLimitError => e
        self.record_ratelimit_error_request_log(
          error: e,
          target_calender_id: target_calender_id,
          calender_event_id: calender_bot.try(:calender_event_id),
          calender_event_hash: calender_event.to_h,
        )
      end
      event_calendars << calender_bot
    end
    return event_calendars
  end

  def remove_calender!(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    service = GoogleServices.get_calender_service(refresh_token: refresh_token)
    calenders = service.list_calendar_lists
    target_calender = calenders.items.detect { |item| item.summary == self.class.calender_title }
    target_calender_id = target_calender.try(:id)
    if target_calender_id.present?
      result = service.delete_event(target_calender_id, self.calender_event_id)
      destroy!
    end
  end

  def self.remove_all_deplicate_events(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    service = GoogleServices.get_calender_service(refresh_token: refresh_token)
    calenders = service.list_calendar_lists
    target_calender = calenders.items.detect { |item| item.summary == self.calender_title }
    return false if target_calender.blank?
    next_page_token = nil
    loop do
      calender_events = service.list_events(target_calender.id, page_token: next_page_token, max_results: 2500)
      calender_events.items.each do |calender_event|
        unless EventCalendarBot.exists?(calender_event_id: calender_event.id)
          service.delete_event(target_calender.id, calender_event.id)
        end
      end
      next_page_token = calender_events.next_page_token
      break if next_page_token.blank?
    end
    return true
  end

  private

  def self.record_ratelimit_error_request_log(error:, target_calender_id:, calender_event_id:, calender_event_hash:)
    logger = ActiveSupport::Logger.new('log/request_error.log')
    console = ActiveSupport::Logger.new(STDOUT)
    logger.extend ActiveSupport::Logger.broadcast(console)
    message = {
      error_message: error.message,
      target_calender_id: target_calender_id,
      calender_event_id: calender_event_id,
      calender_event: calender_event_hash,
    }.to_json
    logger.info(message)
  end
end
