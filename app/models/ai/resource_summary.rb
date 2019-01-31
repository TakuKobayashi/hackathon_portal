# == Schema Information
#
# Table name: ai_resource_summaries
#
#  id            :bigint(8)        not null, primary key
#  resource_type :string(255)      not null
#  resource_id   :integer          not null
#  body          :text(65535)      not null
#  order_number  :integer          default(0), not null
#
# Indexes
#
#  index_ai_resource_summaries_on_resource_type_and_resource_id  (resource_type,resource_id)
#

class Ai::ResourceSummary < ApplicationRecord
  include Dumpdb

  belongs_to :resource, polymorphic: true, required: false
end
