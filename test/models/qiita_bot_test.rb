# == Schema Information
#
# Table name: qiita_bots
#
#  id            :integer          not null, primary key
#  qiita_id      :string(255)      not null
#  title         :string(255)      not null
#  url           :string(255)      not null
#  season_number :integer          not null
#  tag_names     :string(255)
#  event_ids     :text(65535)      not null
#  body          :text(16777215)   not null
#  rendered_body :text(16777215)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_qiita_bots_on_qiita_id       (qiita_id) UNIQUE
#  index_qiita_bots_on_season_number  (season_number)
#

require 'test_helper'

class QiitaBotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
