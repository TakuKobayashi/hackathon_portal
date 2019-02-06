# == Schema Information
#
# Table name: blogger_bots
#
#  id            :bigint(8)        not null, primary key
#  blogger_id    :string(255)      not null
#  title         :string(255)      not null
#  url           :string(255)      not null
#  season_number :integer          not null
#  tag_names     :string(255)
#  event_type    :string(255)
#  event_ids     :text(65535)      not null
#  body          :text(16777215)   not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_blogger_bots_on_blogger_id     (blogger_id) UNIQUE
#  index_blogger_bots_on_season_number  (season_number)
#

require 'test_helper'

class BloggerBotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
