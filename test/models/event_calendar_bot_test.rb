# == Schema Information
#
# Table name: event_calendar_bots
#
#  id                :integer          not null, primary key
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

require 'test_helper'

class EventCalendarBotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
