module RequestParser
  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http_client.send(method, url, params, header)
    doc = Nokogiri::HTML.parse(response.body)
    return doc
  end

  def self.request_and_parse_json(url: ,method: :get, params: {}, header: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http_client.send(method, url, params, header)
    parsed_json = {}
    begin
      parsed_json = JSON.parse(response.body)
    rescue JSON::ParserError => e
      logger = ActiveSupport::Logger.new("log/json_parse_error.log")
      console = ActiveSupport::Logger.new(STDOUT)
      logger.extend ActiveSupport::Logger.broadcast(console)
      message = "Request URL:" + url + "\nRequest Method:" + method.to_s + "\nRequest Params:" + params.to_json + "\nerror: #{e.message}\n #{e.backtrace.join("\n")}\n\n"
      logger.info(message)
    end
    return parsed_json
  end
end