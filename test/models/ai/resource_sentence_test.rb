# == Schema Information
#
# Table name: ai_resource_sentences
#
#  id                :bigint(8)        not null, primary key
#  tweet_resource_id :integer          not null
#  body              :text(65535)      not null
#
# Indexes
#
#  index_ai_resource_sentences_on_tweet_resource_id  (tweet_resource_id)
#

require 'test_helper'

class Ai::ResourceSentenceTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
