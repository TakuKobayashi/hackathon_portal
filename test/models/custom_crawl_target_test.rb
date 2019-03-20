# == Schema Information
#
# Table name: custom_crawl_targets
#
#  id                            :integer          not null, primary key
#  parse_genre                   :integer          default("html"), not null
#  title                         :string(255)      default(""), not null
#  root_url                      :string(255)      not null
#  path                          :string(255)
#  query_hash                    :text(65535)
#  max_crawl_loop_count          :integer
#  activate                      :boolean          default(TRUE), not null
#  filter_words                  :text(65535)
#  correspond_column_filter_json :text(65535)
#  loop_counter                  :integer          default(0), not null
#  last_crawled_at               :datetime
#  crawled_counter               :integer          default(0), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_custom_crawl_targets_on_root_url  (root_url)
#

require "test_helper"

class CustomCrawlTargetTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
