class Peatix < Event
  PEATIX_SEARCH_URL = "http://peatix.com/search"

  def self.find_event(keywords:, start: 1)
    dom = ApplicationRecord.request_and_parse_html(url: PEATIX_SEARCH_URL, params: {q: keywords.join(" ")})
    return dom
  end

  def self.import_events!
  end
end
