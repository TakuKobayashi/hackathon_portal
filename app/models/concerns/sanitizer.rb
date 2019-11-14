module Sanitizer
  module RegexParts
    HTML_COMMENT = '<!--(.*)-->'
    HTML_SCRIPT_TAG = '<script[^>]+?\/>|<script(.|\s)*?\/script>'
  end

  def self.delete_html_comment(text)
    return text.gsub(/#{RegexParts::HTML_COMMENT}/, '')
  end

  def self.delete_javascript_in_html(text)
    return text.gsub(/#{RegexParts::HTML_SCRIPT_TAG}/, '')
  end

  def self.delete_empty_words(text)
    return text.gsub(/\r|\n|\t/, '')
  end

  def self.scan_japan_address(text)
    return text.scan(
      /(...??[都道府県])((?:旭川|伊達|石狩|盛岡|奥州|田村|南相馬|那須塩原|東村山|武蔵村山|羽村|十日町|上越|富山|野々市|大町|蒲郡|四日市|姫路|大和郡山|廿日市|下松|岩国|田川|大村)市|.+?郡(?:玉村|大町|.+?)[町村]|.+?市.+?区|.+?[市区町村])(.+)/
    )
  end

  def self.scan_hash_tags(text)
    return text.scan(/[#＃][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー]+/).map(&:strip)
  end

  def self.scan_urls(text)
    return text.scan(%r{(https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)}).map(&:join)
  end

  def self.scan_ymd_date(text)
    return text.scan(/(\d{4}[.\|\-\/年])(\d{1,2}[.\|\-\/月])(\d{1,2}[日]?)/).map(&:join)
  end

  def self.scan_md_date(text)
    return text.scan(/(\d{1,2}[.\|\-\/月])(\d{1,2}[日]?)/).map(&:join)
  end

  def self.scan_hm_time(text)
    return text.scan(/(\d{1,2}[:時])(\d{1,2}[分]?)/).map(&:join)
  end

  def self.match_address_text(text)
    return text.match(/[\p{Hiragana}|\p{Katakana}|[一-龠々]|\-|\ |0-9|a-z]+/).to_s
  end

  #記号を除去
  def self.delete_symbols(text)
    return text.gsub(
      %r{[【】、。《》「」〔〕・（）［］｛｝！＂＃＄％＆＇＊＋，－．／：；＜＝＞？＠＼＾＿｀｜￠￡￣\(\)\[\]<>{},!? \.\-\+\\~^='&%$#\"\'_\/;:*‼•一]},
      ''
    )
  end

  def self.delete_hashtag_and_replyes(text)
    return text.gsub(/[#＃@][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー_]+/, '')
  end

  def self.delete_urls(text)
    return text.gsub(%r{(https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)}, '')
  end

  def self.delete_sharp(text)
    return text.gsub(/[#＃]/, '')
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
