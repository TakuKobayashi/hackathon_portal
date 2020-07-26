require 'xmlsimple'

module RequestParser
  def self.request_and_parse_html(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    response =
      self.request_and_response(url: url, method: method, params: params, header: header, body: body, options: options)
    text =
      response.try(:body).to_s.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')
    doc = Nokogiri::HTML.parse(text)
    return doc
  end

  def self.request_and_get_links_from_html(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    doc =
      self.request_and_parse_html(
        url: url, method: method, params: params, header: header, body: body, options: options,
      )
    result = {}
    doc.css('a').select { |anchor| anchor[:href].present? && anchor[:href] != '/' }.each do |anchor|
      result[anchor[:href]] = anchor.text
    end
    return result
  end

  def self.request_and_parse_json(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    response =
      self.request_and_response(url: url, method: method, params: params, header: header, body: body, options: options)
    text =
      response.try(:body).to_s.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')
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
        insert_top_messages: ['exception:' + e.class.to_s],
      )
    end
    return parsed_json
  end

  def self.request_and_parse_xml(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    response =
      self.request_and_response(url: url, method: method, params: params, header: header, body: body, options: options)
    text =
      response.try(:body).to_s.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')
    parsed_xml = XmlSimple.xml_in(text)
    return parsed_xml
  end

  def self.request_and_response(url:, method: :get, params: {}, header: {}, body: {}, options: {})
    option_struct = OpenStruct.new(options)
    customize_force_redirect = option_struct.customize_force_redirect
    customize_redirect_counter = option_struct.customize_redirect_counter.to_i
    timeout_second = option_struct.timeout_second || 600
    option_struct.delete_field(:timeout_second) if option_struct.timeout_second.present?

    if customize_force_redirect.present?
      option_struct.delete_field(:customize_force_redirect)
      option_struct.delete_field(:customize_redirect_counter) if option_struct.customize_redirect_counter.present?
      option_struct.delete_field(:follow_redirect) if option_struct.follow_redirect.present?
    end
    http_client = HTTPClient.new
    http_client.connect_timeout = timeout_second
    http_client.send_timeout = timeout_second
    http_client.receive_timeout = timeout_second
    response = nil
    begin
      request_option_hash = { query: params, header: header, body: body }.merge(option_struct.to_h)
      request_option_hash.delete_if { |k, v| v.blank? }
      response = http_client.send(method, url, request_option_hash)
      if response.status >= 400
        self.record_log(
          url: url,
          method: method,
          params: params,
          header: header,
          options: options,
          insert_top_messages: ["request Error Status Code: #{response.status}"],
        )
      end
    rescue SocketError,
           HTTPClient::ConnectTimeoutError,
           HTTPClient::BadResponseError,
           Addressable::URI::InvalidURIError => e
      self.record_log(
        url: url,
        method: method,
        params: params,
        header: header,
        options: options,
        error_messages: ["error: #{e.message}"] + e.backtrace,
        insert_top_messages: ['exception:' + e.class.to_s],
      )
    end
    if customize_force_redirect.present? && response.present? && 300 <= response.status && response.status < 400 &&
         response.headers['Location'].present? && customize_redirect_counter < 5
      redirect_url = response.headers['Location']
      if redirect_url.present?
        redirect_full_url = WebNormalizer.merge_full_url(src: redirect_url, org: url)
        response =
          self.request_and_response(
            url: redirect_full_url,
            options: {
              customize_force_redirect: true,
              customize_redirect_counter: customize_redirect_counter + 1,
              timeout_second: timeout_second,
            },
          )
      end
    end
    return response
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
      'Request Options:' + options.to_json,
    ]
    message = (insert_top_messages + messages + error_messages).join("\n") + "\n\n"
    logger.info(message)
  end
end
