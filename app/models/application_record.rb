class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {})
    http_client = HTTPClient.new
    response = http_client.send(method, url, params, header)
    doc = Nokogiri::HTML.parse(response.body)
    return doc
  end
end
