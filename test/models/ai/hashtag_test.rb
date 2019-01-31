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

require 'test_helper'

class Ai::HashtagTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
