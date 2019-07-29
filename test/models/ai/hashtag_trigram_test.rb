# == Schema Information
#
# Table name: ai_hashtag_trigrams
#
#  id         :bigint           not null, primary key
#  trigram_id :integer          not null
#  hashtag_id :integer          not null
#
# Indexes
#
#  index_ai_hashtag_trigrams_on_hashtag_id  (hashtag_id)
#  index_ai_hashtag_trigrams_on_trigram_id  (trigram_id)
#

require 'test_helper'

class Ai::HashtagTrigramTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
