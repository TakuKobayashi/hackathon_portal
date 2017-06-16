# == Schema Information
#
# Table name: qiita_bots
#
#  id             :integer          not null, primary key
#  qiita_id       :string(255)      not null
#  title          :string(255)      not null
#  url            :string(255)      not null
#  term_range_min :datetime         not null
#  term_range_max :datetime         not null
#  tag_names      :string(255)
#  event_ids      :text(65535)      not null
#  body           :text(65535)      not null
#  rendered_body  :text(65535)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_qiita_bots_on_qiita_id                           (qiita_id) UNIQUE
#  index_qiita_bots_on_term_range_min_and_term_range_max  (term_range_min,term_range_max)
#

require 'test_helper'

class QiitaBotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
