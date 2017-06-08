namespace :batch do
  task work: :environment do
    Event.import_events!
    Event.where("started_at > ? AND limit_number > attend_number", Time.current).find_each do |event|
      sanitized_title = ApplicationRecord.basic_sanitize(event.title).downcase
      keyword = Event::HACKATHON_KEYWORDS.detect{|word| sanitized_title.include?("word") }
      if keyword.present?
        tweet_words = ["#{keyword}情報!!", event.title, event.url, "定員:#{event.limit_number}名 残りあと#{event.limit_number - event.attend_number}名", "#hackathon"]
        TwitterBot.tweet!(text: tweet_words.join("\n") , from: event)
      end
    end
  end
end