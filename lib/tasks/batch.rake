require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "google/apis/slides_v1"

require "fileutils"

namespace :batch do
  task event_bot_tweet: :environment do
    will_post_events = Event.active.where.not(type: nil).where("? < started_at AND started_at < ?", Time.current, 1.year.since).order("started_at ASC")
    future_events = []
    will_post_events.each do |event|
      if event.url_active?
        future_events << event
      else
        event.closed!
      end
    end
    will_post_events += Event.where.not(state: :active, type: nil).where("? < started_at AND started_at < ?", Time.current, 1.year.since).to_a
    will_post_events.sort_by!(&:started_at)
    future_events.each do |event|
      if !TwitterBot.exists?(from: event)
        TwitterBot.tweet!(text: event.generate_tweet_text, access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''), access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''), from: event, options: { lat: event.lat, long: event.lon })
      end
    end
    QiitaBot.post_or_update_article!(events: will_post_events, access_token: ENV.fetch('QIITA_BOT_ACCESS_TOKEN', ''))
    EventCalendarBot.insert_or_update_calender!(events: future_events, refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    BloggerBot.post_or_update_article!(events: will_post_events, blogger_blog_url: 'https://hackathonportal.blogspot.com/', refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
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
