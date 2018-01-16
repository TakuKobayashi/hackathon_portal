module RequestParser
  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {}, options: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    doc = ""
    begin
      response = http_client.send(method, url, {query: params, header: header}.merge(options))
      doc = Nokogiri::HTML.parse(response.body)
    rescue SocketError => e
      record_log(record_log(url: url, method: method, params: params, header: header, options: options, exception: e))
    end
    return doc
  end

  def self.request_and_parse_json(url: ,method: :get, params: {}, header: {}, options: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    parsed_json = {}
    begin
      response = http_client.send(method, url, {query: params, header: header}.merge(options))
      parsed_json = JSON.parse(response.body)
    rescue JSON::ParserError, SocketError => e
      record_log(record_log(url: url, method: method, params: params, header: header, options: options, exception: e))
    end
    return parsed_json
  end

  private
  def self.record_log(url: ,method:, params:, header:, options:, exception:)
    logger = ActiveSupport::Logger.new("log/request_error.log")
    console = ActiveSupport::Logger.new(STDOUT)
    logger.extend ActiveSupport::Logger.broadcast(console)
    message = ([
      "Time:" + Time.current.to_s,
      "exception:" + exception.class.to_s,
      "Request URL:" + url,
      "Request Method:" + method.to_s,
      "Request Headers:" + header.to_json,
      "Request Params:" + params.to_json,
      "Request Options:" + options.to_json,
      "error: #{exception.message}"] + exception.backtrace).join("\n") + "\n\n"
    logger.info(message)
  end
end