# == Schema Information
#
# Table name: ai_appear_words
#
#  id             :bigint           not null, primary key
#  word           :string(255)      not null
#  part           :string(255)      not null
#  reading        :string(255)      not null
#  appear_count   :integer          default(0), not null
#  sentence_count :integer          default(0), not null
#
# Indexes
#
#  index_ai_appear_words_on_reading        (reading)
#  index_ai_appear_words_on_word_and_part  (word,part) UNIQUE
#

require 'test_helper'

class Ai::AppearWordTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
