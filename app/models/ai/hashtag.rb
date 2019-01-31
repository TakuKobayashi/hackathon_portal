# == Schema Information
#
# Table name: ai_hashtags
#
#  id      :bigint(8)        not null, primary key
#  hashtag :string(255)      not null
#
# Indexes
#
#  index_ai_hashtags_on_hashtag  (hashtag)
#

class Ai::Hashtag < ApplicationRecord
  include Dumpdb

  has_many :resource_hashtags, class_name: 'Ai::ResourceHashtag', foreign_key: :hashtag_id
end
