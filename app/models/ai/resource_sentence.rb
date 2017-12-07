# == Schema Information
#
# Table name: ai_resource_sentences
#
#  id                :integer          not null, primary key
#  tweet_resource_id :integer          not null
#  body              :text(65535)      not null
#
# Indexes
#
#  index_ai_resource_sentences_on_tweet_resource_id  (tweet_resource_id)
#

class Ai::ResourceSentence < ApplicationRecord
  belongs_to :tweet_resource, class_name: 'Ai::TweetResource', foreign_key: :tweet_resource_id, required: false
  has_many :trigrams, class_name: 'Ai::Trigram', foreign_key: :sentence_id
end
