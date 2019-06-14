# == Schema Information
#
# Table name: ai_resource_attachments
#
#  id                :bigint(8)        not null, primary key
#  tweet_resource_id :integer          not null
#  category          :integer          default("website"), not null
#  origin_src        :string(255)      not null
#  query             :text(65535)
#  options           :text(65535)
#
# Indexes
#
#  ai_resource_attachments_resource_and_category_index  (tweet_resource_id,category)
#  index_ai_resource_attachments_on_origin_src          (origin_src)
#

require 'test_helper'

class Ai::ResourceAttachmentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
