# == Schema Information
#
# Table name: ai_resource_hashtags
#
#  id            :bigint(8)        not null, primary key
#  resource_type :string(255)      not null
#  resource_id   :integer          not null
#  hashtag_id    :integer          not null
#
# Indexes
#
#  ai_resource_hashtags_unique_index         (resource_type,resource_id,hashtag_id) UNIQUE
#  index_ai_resource_hashtags_on_hashtag_id  (hashtag_id)
#

class Ai::ResourceHashtag < ApplicationRecord
  include Dumpdb

  belongs_to :resource, polymorphic: true, required: false
  belongs_to :hashtag, class_name: 'Ai::Hashtag', foreign_key: :hashtag_id, required: false
end
