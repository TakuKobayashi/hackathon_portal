namespace :batch do
  task crawl_and_tweet: :environment do
    Event.import_events!
    Event.where("started_at > ?", Time.current).find_each do |event|
      if event.hackathon_event?
        TwitterBot.tweet!(text: event.generate_tweet_text, from: event, options: {lat: event.lat, long: event.lon})
      end
    end
  end
end