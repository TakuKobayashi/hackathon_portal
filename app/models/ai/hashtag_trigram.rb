# == Schema Information
#
# Table name: ai_hashtag_trigrams
#
#  id         :bigint(8)        not null, primary key
#  trigram_id :integer          not null
#  hashtag_id :integer          not null
#
# Indexes
#
#  index_ai_hashtag_trigrams_on_hashtag_id  (hashtag_id)
#  index_ai_hashtag_trigrams_on_trigram_id  (trigram_id)
#

class Ai::HashtagTrigram < ApplicationRecord
  belongs_to :trigram, class_name: "Ai::Trigram", foreign_key: :trigram_id, required: false
  belongs_to :hashtag, class_name: "Ai::Hashtag", foreign_key: :hashtag_id, required: false
end
