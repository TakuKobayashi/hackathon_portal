# == Schema Information
#
# Table name: ai_tweet_resources
#
#  id                 :integer          not null, primary key
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

class Ai::TwitterResource < Ai::TweetResource
  def self.crawl_hashtag_tweets!
    crawl_ids = Log::Crawl.where("crawled_at > ?", 6.day.ago).where(from_type: "Ai::Hashtag").pluck(:from_id)
    events = []
    Event.preload(:hashtags).find_each do |event|
      if event.hackathon_event? && event.hashtags.all?{|hashtag| !crawl_ids.include?(hashtag.id)}
        events << event
      end
    end
    hashtags = events.map(&:hashtags).flatten.uniq
    twitter_client = TwitterBot.get_twitter_client
    hashtags.each do |hashtag|
      tweets = []
      begin
        tweets = twitter_client.search("#" + hashtag.hashtag)
      rescue Twitter::Error::Forbidden, Twitter::Error::ServiceUnavailable, Twitter::Error::ClientError, Twitter::Error::ServerError => error
        break
      end
      rid_resources = Ai::TwitterResource.where(resource_id: tweets.map(&:id)).index_by(&:resource_id)
      tweets.each do |tweet|
        next if rid_resources[tweet.id.to_s].present?
        Ai::TwitterResource.transaction do
          ai_resource = Ai::TwitterResource.new(
            resource_id: tweet.id,
            resource_user_id: tweet.user.id.to_s,
            resource_user_name: tweet.user.screen_name,
            body: Sanitizer.basic_sanitize(tweet.text),
            published_at: tweet.created_at
          )
          if tweet.in_reply_to_tweet_id.present?
            ai_resource.reply_id = tweet.in_reply_to_tweet_id
          end
          if tweet.quoted_tweet.present?
            ai_resource.quote_id = tweet.quoted_tweet.id
          end
          ai_resource.options = {
            mentions: tweet.user_mentions.map{|m| {user_id: m.id, user_name: m.screen_name} }
          }
          ai_resource.save!
          ai_resource.register_hashtags!(tweet: tweet)
          ai_resource.register_attachments!(tweet: tweet)
        end
      end
      crawl = Log::Crawl.find_or_initialize_by(from: hashtag)
      crawl.update!(crawled_at: Time.current)
    end
  end

  def register_hashtags!(tweet: tweet)
    ai_hashtags = Ai::Hashtag.where(hashtag: tweet.hashtags.map(&:text)).index_by(&:hashtag)
    import_ai_hashtags = []
    tweet.hashtags.each do |ht|
      if ai_hashtags[ht.text].present?
        import_ai_hashtags << self.hashtags.new(hashtag_id: ai_hashtags[ht.text].id)
      else
        new_hashtag = Ai::Hashtag.create!(hashtag: ht.text)
        import_ai_hashtags << self.hashtags.new(hashtag_id: new_hashtag.id)
      end
    end
    if import_ai_hashtags.present?
      Ai::ResourceHashtag.import!(import_ai_hashtags)
    end
  end

  def register_attachments!(tweet: tweet)
    attachments = []
    tweet.urls.flatten.each do |url|
      attachment = self.attachments.new(category: :website)
      attachment.src = url.expanded_url.to_s
      attachments << attachment
    end
    tweet.media.flatten.each do |m|
      case m
      when Twitter::Media::Photo
        attachment = self.attachments.new(category: :image)
        attachment.src = m.media_url.to_s
        attachments << attachment
      when Twitter::Media::Video
        attachment = self.attachments.new
        max_bitrate_variant = m.video_info.variants.max_by{|variant| variant.bitrate.to_i }
        if max_bitrate_variant.present?
          attachment.category = :image
          attachment.src = m.media_url.to_s
        else
          attachment.category = :video
          attachment.src = max_bitrate_variant.try(:url).to_s
        end
        attachments << attachment
      end
    end
    if attachments.present?
      Ai::ResourceAttachment.import!(attachments)
    end
  end
end
