namespace :batch do
  task crawl_and_tweet: :environment do
    Event.import_events!
    Event.where("started_at > ?", Time.current).find_each do |event|
      next if event.limit_number.present? && event.limit_number <= event.attend_number
      sanitized_title = ApplicationRecord.basic_sanitize(event.title).downcase
      keyword = Event::HACKATHON_KEYWORDS.detect{|word| sanitized_title.include?(word) }
      if keyword.present?
        tweet_words = ["#{keyword}情報!!", event.title, event.url, event.started_at.strftime("%Y/%m/%d %H:%M 開始"), event.ended_at.strftime("%Y/%m/%d %H:%M 終了")]
        if event.limit_number.present?
          tweet_words << "定員:#{event.limit_number}名 残りあと#{event.limit_number - event.attend_number}名"
        else
          tweet_words << "現在:#{event.attend_number}名参加中!!"
        end
        tweet_words += ["#hackathon"]
        TwitterBot.tweet!(text: tweet_words.join("\n") , from: event, options: {lat: event.lat, long: event.lon})
      end
    end
  end
end