# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  keyword           :string(255)      not null
#  title             :string(255)      not null
#  url               :string(255)      not null
#  description       :string(255)      not null
#  started_at        :datetime         not null
#  ended_at          :datetime         not null
#  limit_number      :integer          default(0), not null
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
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_keyword                  (keyword)
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
