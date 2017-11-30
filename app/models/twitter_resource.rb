# == Schema Information
#
# Table name: tweet_resources
#
#  id                 :integer          not null, primary key
#  type               :string(255)
#  resource_id        :string(255)      not null
#  resource_user_id   :string(255)
#  resource_user_name :string(255)
#  body               :text(65535)      not null
#  url                :text(65535)
#  hash_tag           :string(255)
#  published_at       :datetime         not null
#  options            :text(65535)
#
# Indexes
#
#  index_tweet_resources_on_hash_tag              (hash_tag)
#  index_tweet_resources_on_published_at          (published_at)
#  index_tweet_resources_on_resource_id_and_type  (resource_id,type) UNIQUE
#

class TwitterResource < TweetResource
  def self.crawl!
    client = TwitterBot.get_twitter_client
    Event.find_each do |event|
      if event.hash_tag.present?
        hashtags = event.hash_tag.to_s.split(" #")
        hashtags.each do |hashtag|
          client.search(hashtag)
        end
      end
    end
  end
end
