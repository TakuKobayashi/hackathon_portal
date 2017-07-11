module Sanitizer
  def self.delete_html_comment(text)
    return text.gsub(/<!--(.*)-->/, "")
  end

  def self.delete_javascript_in_html(text)
    return text.gsub(/<script[^>]+?\/>|<script(.|\s)*?\/script>/, "")
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