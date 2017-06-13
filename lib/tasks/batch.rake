namespace :batch do
  task crawl_and_tweet: :environment do
    Event.import_events!
    Event.where("started_at > ?", Time.current).find_each do |event|
      next if event.limit_number.present? && event.limit_number <= event.attend_number
      sanitized_title = ApplicationRecord.basic_sanitize(event.title).downcase
      keyword = Event::HACKATHON_KEYWORDS.detect{|word| sanitized_title.include?(word) }
      if keyword.present?
        TwitterBot.tweet!(text: event.generate_tweet_text, from: event, options: {lat: event.lat, long: event.lon})
      end
    end
  end
end