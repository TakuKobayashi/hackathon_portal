require 'xmlsimple'

module RequestParser
  def self.request_and_parse_html(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    text = self.request_and_response_body(url: url, method: method, params: params, header: header, body: body, options: options)
    doc = Nokogiri::HTML.parse(text)
    return doc
  end

  def self.request_and_get_links_from_html(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    doc = self.request_and_parse_html(url: url, method: method, params: params, header: header, body: body, options: options)
    result = {}
    doc.css('a').select { |anchor| anchor[:href].present? && anchor[:href] != '/' }.each { |anchor| result[anchor[:href]] = anchor.text }
    return result
  end

  def self.request_and_parse_json(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    text = self.request_and_response_body(url: url, method: method, params: params, header: header, body: body, options: options)
    parsed_json = {}
    begin
      parsed_json = JSON.parse(text)
    rescue JSON::ParserError => e
      self.record_log(
        url: url,
        method: method,
        params: params,
        header: header,
        options: options,
        error_messages: ["error: #{e.message}"] + e.backtrace,
        insert_top_messages: ['exception:' + e.class.to_s]
      )
    end
    return parsed_json
  end

  def self.request_and_parse_xml(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    text = self.request_and_response_body(url: url, method: method, params: params, header: header, body: body, options: options)
    parsed_xml = XmlSimple.xml_in(text)
    return parsed_xml
  end

  def self.request_and_response_body(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    http_client = HTTPClient.new
    http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http_client.connect_timeout = 600
    http_client.send_timeout = 600
    http_client.receive_timeout = 600
    result = ''
    begin
      request_option_hash = { query: params, header: header, body: body }.merge(options)
      request_option_hash.delete_if { |k, v| v.blank? }
      response = http_client.send(method, url, request_option_hash)
      if response.status >= 400
        self.record_log(
          url: url,
          method: method,
          params: params,
          header: header,
          options: options,
          insert_top_messages: ["request Error Status Code: #{response.status}"]
        )
      end
      result = response.body
    rescue SocketError, HTTPClient::ConnectTimeoutError, HTTPClient::BadResponseError, Addressable::URI::InvalidURIError => e
      self.record_log(
        url: url,
        method: method,
        params: params,
        header: header,
        options: options,
        error_messages: ["error: #{e.message}"] + e.backtrace,
        insert_top_messages: ['exception:' + e.class.to_s]
      )
    end
    return result
  end

  private

  def self.record_log(url:, method:, params:, header:, options:, error_messages: [], insert_top_messages: [])
    logger = ActiveSupport::Logger.new('log/request_error.log')
    console = ActiveSupport::Logger.new(STDOUT)
    logger.extend ActiveSupport::Logger.broadcast(console)
    messages = [
      'Time:' + Time.current.to_s,
      'Request URL:' + url,
      'Request Method:' + method.to_s,
      'Request Headers:' + header.to_json,
      'Request Params:' + params.to_json,
      'Request Options:' + options.to_json
    ]
    message = (insert_top_messages + messages + error_messages).join("\n") + "\n\n"
    logger.info(message)
  end
end
