# == Schema Information
#
# Table name: ai_trigrams
#
#  id                :integer          not null, primary key
#  tweet_resource_id :integer          not null
#  position_genre    :integer          default(0), not null
#  first_word        :string(255)      default(""), not null
#  second_word       :string(255)      default(""), not null
#  third_word        :string(255)      default(""), not null
#
# Indexes
#
#  index_ai_trigrams_on_first_word_and_position_genre  (first_word,position_genre)
#  index_ai_trigrams_on_tweet_resource_id              (tweet_resource_id)
#

class Ai::Trigram < ApplicationRecord
  belongs_to :sentence, class_name: 'Ai::ResourceSentence', foreign_key: :sentence_id, required: false
  belongs_to :tweet_resource, class_name: 'Ai::TweetResource', foreign_key: :tweet_resource_id, required: false
end
