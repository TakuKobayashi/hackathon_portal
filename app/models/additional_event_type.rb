# == Schema Information
#
# Table name: additional_event_types
#
#  id         :bigint           not null, primary key
#  event_id   :integer          not null
#  event_type :string(255)      not null
#
# Indexes
#
#  index_additional_event_types_on_event_id  (event_id)
#

class AdditionalEventType < ApplicationRecord
  belongs_to :event, class_name: 'Event', foreign_key: :event_id, required: false
end
