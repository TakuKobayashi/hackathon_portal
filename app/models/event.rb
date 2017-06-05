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

class Event < ApplicationRecord
end
