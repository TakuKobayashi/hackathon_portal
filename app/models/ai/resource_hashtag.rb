# == Schema Information
#
# Table name: ai_resource_hashtags
#
#  id            :integer          not null, primary key
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
end
