module DevpostOperation
  DEVPOST_HACKATHONS_URL = 'https://devpost.com/hackathons'

  def self.imoport_hackathon_events!
    page = 1
    doc = RequestParser.request_and_parse_html(url: DEVPOST_HACKATHONS_URL, params: { page: page })
  end
end
