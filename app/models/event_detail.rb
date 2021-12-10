# == Schema Information
#
# Table name: event_details
#
#  id            :bigint           not null, primary key
#  event_id      :bigint           not null
#  description   :text(65535)
#  og_image_info :text(65535)
#
# Indexes
#
#  index_event_details_on_event_id  (event_id)
#
class EventDetail < ApplicationRecord
  serialize :og_image_info, JSON
end
