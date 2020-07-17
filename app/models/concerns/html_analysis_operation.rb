module HtmlAnalysisOperation
  def self.get_natto
    return Natto::MeCab.new(dicdir: ENV.fetch('MECAB_NEOLOGD_DIC_PATH', ''))
  end

  def self.request_and_analyze(url:)
    doc = RequestParser.request_and_parse_html(url: url)
    #    doc.title
    plane_body_doc = Nokogiri::HTML.parse(Sanitizer.delete_javascript_in_html(doc.css('body').to_html))
  end
end
