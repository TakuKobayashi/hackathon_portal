namespace :batch do
  task crawl_and_tweet: :environment do
    Event.import_events!
    Event.where("started_at > ?", Time.current).find_each do |event|
      next if event.limit_number.present? && event.limit_number <= event.attend_number
      sanitized_title = ApplicationRecord.basic_sanitize(event.title).downcase
      keyword = Event::HACKATHON_KEYWORDS.detect{|word| sanitized_title.include?(word) }
      if keyword.present?
        tweet_words = [event.title, event.url, event.started_at.strftime("開催日:%Y年%m月%d日")]
        tweet_words += ["#hackathon"]
        text_size = 0
        tweet_words.select! do |text|
          text_size += text.size
          text_size <= 140
        end
        text = tweet_words.join("\n")
        TwitterBot.tweet!(text: text, from: event, options: {lat: event.lat, long: event.lon})
      end
    end
  end
end