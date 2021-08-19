# == Schema Information
#
# Table name: ai_tweet_resources
#
#  id                 :bigint           not null, primary key
#  type               :string(255)
#  resource_id        :string(255)      not null
#  resource_user_id   :string(255)
#  resource_user_name :string(255)
#  body               :text(65535)      not null
#  mention_user_name  :string(255)
#  reply_id           :string(255)
#  quote_id           :string(255)
#  published_at       :datetime         not null
#  options            :text(65535)
#
# Indexes
#
#  index_ai_tweet_resources_on_published_at          (published_at)
#  index_ai_tweet_resources_on_resource_id_and_type  (resource_id,type) UNIQUE
#

class Ai::TweetResource < ApplicationRecord
  serialize :options, JSON

  has_many :summaries, as: :resource, class_name: 'Ai::ResourceSummary'
  has_many :hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'
  has_many :trigrams, class_name: 'Ai::Trigram', foreign_key: :tweet_resource_id
  has_many :sentences, class_name: 'Ai::ResourceSentence', foreign_key: :tweet_resource_id
  has_many :attachments, class_name: 'Ai::ResourceAttachment', foreign_key: :tweet_resource_id

  def plane_text_body
    sanitized_body = Sanitizer.delete_urls(self.body)
    return Sanitizer.delete_hashtag_and_replyes(sanitized_body).strip
  end

  def regist_split_sentence!
    return self.sentences if self.sentences.present?
    import_sentences = []
    split_sentences = plane_text_body.split(/[。．.？！!?\n\r]/)
    transaction do
      split_sentences.each do |sentence|
        import_sentences << self.sentences.create!(body: sentence) if sentence.present?
      end
    end
    return import_sentences
  end

  def split_and_sanitize_morphological_analysis
    xml_hash =
      RequestParser.request_and_parse_xml(
        url: 'https://jlp.yahooapis.jp/MAService/V1/parse',
        params: {
          appid: ENV.fetch('YAHOO_API_CLIENT_ID', ''),
          sentence: plane_text_body,
        },
        options: {
          follow_redirect: true,
        },
      )
    words =
      xml_hash['ma_result'].first['word_list'].first['word'].map { |hash| hash['surface'] }.flatten.select(&:present?)
    return words
  end

  def regist_split_trigrams!(words: [])
    return self.trigrams if self.trigrams.present?
    import_trigrams = []
    transaction do
      words
        .each_cons(3)
        .with_index do |emu_cons_words, index|
          cons_words = emu_cons_words.flatten
          trigram = nil
          if index == 0
            trigram = self.trigrams.new(position_genre: :bos)
          elsif index == words.size - 3
            trigram = self.trigrams.new(position_genre: :eos)
          else
            trigram = self.trigrams.new(position_genre: :general)
          end
          if trigram.present?
            trigram.update!(first_word: cons_words[0], second_word: cons_words[1], third_word: cons_words[2])
            import_trigrams << trigram
          end
        end
    end
    return import_trigrams
  end
end
