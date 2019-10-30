class AdditionalEventType < ApplicationRecord
  belongs_to :event, class_name: 'Event', foreign_key: :event_id, required: false
end
