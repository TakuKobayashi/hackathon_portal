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
#  ended_at          :datetime         not null
#  limit_number      :integer
#  address           :string(255)
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
#  informed_from     :integer          default("web"), not null
#  state             :integer          default("active"), not null
#  og_image_info     :text(65535)
#
# Indexes
#
#  index_events_on_ended_at                    (ended_at)
#  index_events_on_event_id_and_informed_from  (event_id,informed_from)
#  index_events_on_started_at                  (started_at)
#  index_events_on_url                         (url)
#

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
