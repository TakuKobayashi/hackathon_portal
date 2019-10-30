require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "google/apis/slides_v1"

require "fileutils"

namespace :batch do
  task event_crawl: :environment do
    Event.import_events!
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start
    Scaling::UnityEvent.import_events!
  end

  task event_bot_tweet: :environment do
    future_events = Event.before_judge.where("? < started_at AND started_at < ?", Time.current, 1.year.since).order("started_at ASC").select { |event| event.hackathon_event? }
    future_events.each do |event|
      if !TwitterBot.exists?(from: event)
        TwitterBot.tweet!(text: event.generate_tweet_text, from: event, options: { lat: event.lat, long: event.lon })
      end
    end
    QiitaBot.post_or_update_article!(events: future_events)
    EventCalendarBot.insert_or_update_calender!(events: future_events)
    BloggerBot.post_or_update_article!(events: future_events)
  end

  task generate_slide: :environment do
    service = Google::Apis::SlidesV1::SlidesService.new
    service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    presentation = Google::Apis::SlidesV1::Presentation.new(title: "slide_name")
    new_presentation = service.create_presentation(presentation)

    create_slide = Google::Apis::SlidesV1::CreateSlideRequest.new
    request = Google::Apis::SlidesV1::Request.new(create_slide: create_slide)
    batch = Google::Apis::SlidesV1::BatchUpdatePresentationRequest.new(requests: [request])
    batch.update!(requests: [request])
    service.batch_update_presentation(new_presentation.presentation_id, batch, {})
  end
end
