module RequestParser
  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http_client.send(method, url, params, header)
    doc = Nokogiri::HTML.parse(response.body)
    return doc
  end
end