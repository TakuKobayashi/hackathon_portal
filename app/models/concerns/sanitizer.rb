module Sanitizer
  module RegexpParts
    HTML_COMMENT = '<!--(.*)-->'
    HTML_SCRIPT_TAG = '<script[^>]+?\/>|<script(.|\s)*?\/script>'
    HTML_HEADER_TAG = '<header[^>]+?\/>|<header(.|\s)*?\/header>'
    HTML_FOOTER_TAG = '<footer[^>]+?\/>|<footer(.|\s)*?\/footer>'
    HTML_LINK_TAG = '<link[^>]+?\/>|<link(.|\s)*?\/link>'
    HTML_STYLE_TAG = '<style[^>]+?\/>|<style(.|\s)*?\/style>'
    HTML_IFRAME_TAG = '<iframe[^>]+?\/>|<iframe(.|\s)*?\/iframe>'
    HTML_ARTICLE_TAG = '<article[^>]+?\/>|<article(.|\s)*?\/article>'
    EMPTY_WORD_TAGS = '\r|\n|\t'
    TODOUFUKENLIST = %w[
      北海道
      青森県
      岩手県
      秋田県
      山形県
      宮城県
      福島県
      群馬県
      栃木県
      茨城県
      埼玉県
      東京都
      千葉県
      神奈川県
      新潟県
      長野県
      富山県
      石川県
      福井県
      静岡県
      山梨県
      愛知県
      岐阜県
      滋賀県
      三重県
      奈良県
      和歌山県
      京都府
      大阪府
      兵庫県
      岡山県
      広島県
      鳥取県
      島根県
      山口県
      香川県
      徳島県
      高知県
      愛媛県
      福岡県
      佐賀県
      長崎県
      大分県
      熊本県
      宮崎県
      鹿児島県
      沖縄県
    ]
    SYMBOLLIST = [
      '[',
      '【',
      '】',
      '、',
      '。',
      '《',
      '》',
      '「',
      '」',
      '〔',
      '〕',
      '・',
      '（',
      '）',
      '［',
      '］',
      '｛',
      '｝',
      '！',
      '＂',
      '＃',
      '＄',
      '％',
      '＆',
      '＇',
      '＊',
      '＋',
      '，',
      '－',
      '．',
      '／',
      '：',
      '；',
      '＜',
      '＝',
      '＞',
      '？',
      '＠',
      '＼',
      '＾',
      '＿',
      '｀',
      '｜',
      '￠',
      '￡',
      '￣',
      '　',
      '\\(',
      '\\)',
      '\\[',
      '\\]',
      '<',
      '>',
      '{',
      '}',
      ',',
      '!',
      '?',
      ' ',
      '\\.',
      '\\-',
      '\\+',
      '\\',
      '~',
      '^',
      '=',
      '"',
      "'",
      '&',
      '%',
      '$',
      '#',
      '_',
      '\\/',
      ';',
      ':',
      '*',
      '‼',
      '•',
      '一',
      ']',
    ]
  end

  def self.delete_html_comment(text)
    return text.gsub(/#{RegexpParts::HTML_COMMENT}/, '')
  end

  def self.delete_javascript_in_html(text)
    return text.gsub(/#{RegexpParts::HTML_SCRIPT_TAG}/, '')
  end

  def self.delete_header_tag_in_html(text)
    return text.gsub(/#{RegexpParts::HTML_HEADER_TAG}/, '')
  end

  def self.delete_footer_tag_in_html(text)
    return text.gsub(/#{RegexpParts::HTML_FOOTER_TAG}/, '')
  end

  def self.delete_style_in_html(text)
    return text.gsub(/#{RegexpParts::HTML_STYLE_TAG}/, '')
  end

  def self.delete_empty_words(text)
    return text.gsub(/#{RegexpParts::EMPTY_WORD_TAGS}/, '')
  end

  def self.japan_address_regexp
    return(
      Regexp.new(
        '(' + RegexpParts::TODOUFUKENLIST.join('|') + ')' +
          '((?:旭川|伊達|石狩|盛岡|奥州|田村|南相馬|那須塩原|東村山|武蔵村山|羽村|十日町|上越|富山|野々市|大町|蒲郡|四日市|姫路|大和郡山|廿日市|下松|岩国|田川|大村|宮古|富良野|別府|佐伯|黒部|小諸|塩尻|玉野|周南)市|(?:余市|高市|[^市]{2,3}?)郡(?:玉村|大町|.{1,5}?)[町村]|(?:.{1,4}市)?[^町]{1,4}?区|.{1,7}?[市町村])' +
          '(.+)',
      )
    )
  end

  def self.ymd_date_regexp
    return Regexp.new('(\d{4}[.\|\-\/年]?) ?(\d{1,2}[.\|\-\/月]?) ?(\d{1,2}[日]?)')
  end

  def self.time_regexp
    return Regexp.new('(\d{1,2}[:時])(\d{1,2}[:分]?)(\d{1,2}[秒]?)?')
  end

  def self.online_regexp
    return Regexp.new('(オンライン|online|おんらいん|remote|リモート)')
  end

  def self.empty_words_regexp
    return Regexp.new(RegexpParts::EMPTY_WORD_TAGS)
  end

  def self.scan_candidate_datetime(text)
    results = []
    date_string_parts = text.scan(self.ymd_date_regexp)
    date_string_parts.each do |date_string_part|
      date_string = date_string_part.map(&:to_i).join('-')
      begin
        parsed_date = DateTime.parse(date_string)
        results << parsed_date
      rescue StandardError
      end
    end
    return results
  end

  def self.scan_candidate_time(text)
    results = []
    time_string_parts = text.scan(self.time_regexp)
    time_string_parts.each do |time_string_part|
      time_parts = time_string_part.map(&:to_i)
      results << time_parts
    end
    return results
  end

  def self.scan_japan_address(text)
    return(
      text.scan(
        /(...??[都道府県])((?:旭川|伊達|石狩|盛岡|奥州|田村|南相馬|那須塩原|東村山|武蔵村山|羽村|十日町|上越|富山|野々市|大町|蒲郡|四日市|姫路|大和郡山|廿日市|下松|岩国|田川|大村)市|.+?郡(?:玉村|大町|.+?)[町村]|.+?市.+?区|.+?[市区町村])(.+)/,
      )
    )
  end

  def self.scan_hash_tags(text)
    return text.scan(/[#＃][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー]+/).map(&:strip)
  end

  def self.scan_urls(text)
    return text.scan(%r{(https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)}).map(&:join)
  end

  def self.scan_ymd_date(text)
    return text.scan(%r{(\d{4}[.\|\-\/年])(\d{1,2}[.\|\-\/月])(\d{1,2}[日]?)}).map(&:join)
  end

  def self.scan_md_date(text)
    return text.scan(%r{(\d{1,2}[.\|\-\/月])(\d{1,2}[日]?)}).map(&:join)
  end

  def self.scan_hm_time(text)
    return text.scan(/(\d{1,2}[:時])(\d{1,2}[分]?)/).map(&:join)
  end

  def self.match_address_text(text)
    return text.match(/[\p{Hiragana}|\p{Katakana}|[一-龠々]|\-|\ |0-9|a-z]+/).to_s
  end

  #記号を除去
  def self.delete_symbols(text)
    return(
      text.gsub(%r{[【】、。《》「」〔〕・（）［］｛｝！＂＃＄％＆＇＊＋，－．／：；＜＝＞？＠＼＾＿｀｜￠￡￣\(\)\[\]<>{},!? \.\-\+\\~^='&%$#\"\'_\/;:*‼•一]}, '')
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
    sanitized_word =
      sanitized_word.encode('SJIS', 'UTF-8', invalid: :replace, undef: :replace, replace: '').encode('UTF-8')

    # 余分な空欄を除去
    sanitized_word.strip!
    return sanitized_word
  end
end
