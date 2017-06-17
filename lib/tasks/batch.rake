namespace :batch do
  task crawl_and_tweet: :environment do
    Event.import_events!
    future_events = Event.where("? < started_at AND started_at < ?", Time.current, 1.year.since).order("started_at ASC").select{|event| event.hackathon_event? }
    future_events.each do |event|
      if !TwitterBot.exists?(from: event)
        TwitterBot.tweet!(text: event.generate_tweet_text, from: event, options: {lat: event.lat, long: event.lon})
      end
    end
    QiitaBot.post_or_update_article!(events: future_events)
  end
end