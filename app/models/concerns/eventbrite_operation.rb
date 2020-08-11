module EventbriteOperation
  # https://www.eventbrite.com/
  # https://www.eventbrite.com/platform/api
  EVENTBRITE_API_URL = 'https://www.eventbriteapi.com/'

  def self.import_events_from_keywords!(keywords:)
    self.imoport_gamejam_events!
  end
end
