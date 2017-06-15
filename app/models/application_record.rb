class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.request_and_parse_html(url: ,method: :get, params: {}, header: {})
    http_client = HTTPClient.new
    response = http_client.send(method, url, params, header)
    doc = Nokogiri::HTML.parse(response.body)
    return doc
  end

  def self.basic_sanitize(text)
    #絵文字を除去
    sanitized_word = text.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')
    #全角半角をいい感じに整える
    sanitized_word = Charwidth.normalize(sanitized_word)
    
    # 余分な空欄を除去
    sanitized_word.strip!
    return sanitized_word
  end
end
