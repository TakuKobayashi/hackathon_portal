require 'xmlsimple'

module RequestParser
  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {}, options: {})
    text = self.request_and_response_body_text(url: url,method: method, params: params, header: header, options: options)
    doc = Nokogiri::HTML.parse(text)
    return doc
  end

  def self.request_and_parse_json(url: ,method: :get, params: {}, header: {}, options: {})
    text = self.request_and_response_body_text(url: url,method: method, params: params, header: header, options: options)
    parsed_json = {}
    begin
      parsed_json = JSON.parse(text)
    rescue JSON::ParserError => e
      record_log(url: url, method: method, params: params, header: header, options: options, exception: ["error: #{e.message}"] + e.backtrace)
    end
    return parsed_json
  end

  def self.request_and_parse_xml(url: ,method: :get, params: {}, header: {}, options: {})
    text = self.request_and_response_body_text(url: url,method: method, params: params, header: header, options: options)
    parsed_xml = XmlSimple.xml_in(text)
    return parsed_xml
  end

  def self.request_and_response_body_text(url: ,method: :get, params: {}, header: {}, options: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http_client.connect_timeout = 600
    http_client.send_timeout    = 600
    http_client.receive_timeout = 600
    result = ""
    begin
      response = http_client.send(method, url, {query: params, header: header}.merge(options))
      if response.status >= 400

      end
      result = response.body
    rescue SocketError => e
      record_log(url: url, method: method, params: params, header: header, options: options, error_messages: ["error: #{e.message}"] + e.backtrace)
    end
    return result
  end

  private
  def self.record_log(url: ,method:, params:, header:, options:, error_messages: [], insert_top_messages: [])
    logger = ActiveSupport::Logger.new("log/request_error.log")
    console = ActiveSupport::Logger.new(STDOUT)
    logger.extend ActiveSupport::Logger.broadcast(console)
    messages = [
      "Time:" + Time.current.to_s,
      "exception:" + exception.class.to_s,
      "Request URL:" + url,
      "Request Method:" + method.to_s,
      "Request Headers:" + header.to_json,
      "Request Params:" + params.to_json,
      "Request Options:" + options.to_json,
    ]
    message = (insert_top_messages + messages + error_messages).join("\n") + "\n\n"
    message = ( + exception.backtrace)
    logger.info(message)
  end
end