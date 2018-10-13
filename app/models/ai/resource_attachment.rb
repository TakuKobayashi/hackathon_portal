# == Schema Information
#
# Table name: ai_resource_attachments
#
#  id                :integer          not null, primary key
#  tweet_resource_id :integer          not null
#  category          :integer          default("website"), not null
#  origin_src        :string(255)      not null
#  query             :text(65535)
#  options           :text(65535)
#
# Indexes
#
#  ai_resource_attachments_resource_and_category_index  (tweet_resource_id,category)
#  index_ai_resource_attachments_on_origin_src          (origin_src)
#

class Ai::ResourceAttachment < ApplicationRecord
  include Dumpdb

  serialize :options, JSON

  enum category: {
    website: 0,
    image: 1,
    video: 2
  }

  belongs_to :tweet_resource, class_name: 'Ai::TweetResource', foreign_key: :tweet_resource_id, required: false

  def src
    url = Addressable::URI.parse(self.origin_src)
    url.query = self.query
    return url.to_s
  end

  def src=(url)
    origin_src, query = Ai::ResourceAttachment.url_partition(url: url)
    self.origin_src = origin_src
    self.query = query
  end

  private
  def self.url_partition(url:)
    aurl = Addressable::URI.parse(url)
    pure_url = aurl.origin.to_s + aurl.path.to_s
    if pure_url.size > 255
      word_counter = 0
      srces, other_pathes = pure_url.split("/").partition do |word|
        word_counter = word_counter + word.size + 1
        word_counter <= 255
      end
      return srces.join("/"), other_pathes.join("/")
    else
      return pure_url, aurl.query
    end
  end
end
