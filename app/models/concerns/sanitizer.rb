module Sanitizer
  def self.delete_html_comment(text)
    return text.gsub(/<!--(.*)-->/, "")
  end

  def self.delete_javascript_in_html(text)
    return text.gsub(/<script[^>]+?\/>|<script(.|\s)*?\/script>/, "")
  end

  def self.delete_empty_words(text)
    return text.gsub(/\r|\n|\t/, "")
  end

  def self.scan_japan_address(text)
    return text.scan(/(...??[都道府県])((?:旭川|伊達|石狩|盛岡|奥州|田村|南相馬|那須塩原|東村山|武蔵村山|羽村|十日町|上越|富山|野々市|大町|蒲郡|四日市|姫路|大和郡山|廿日市|下松|岩国|田川|大村)市|.+?郡(?:玉村|大町|.+?)[町村]|.+?市.+?区|.+?[市区町村])(.+)/)
  end

  def self.scan_hash_tags(text)
    return text.scan(/[#＃][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー]+/).map(&:strip)
  end

  def self.basic_sanitize(text)
    #全角半角をいい感じに整える
    sanitized_word = Charwidth.normalize(text)
    #絵文字を除去
    sanitized_word = sanitized_word.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')
    # 余分な空欄を除去
    sanitized_word.strip!
    return sanitized_word
  end
end