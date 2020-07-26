module NokogiriSearcher
  def self.find_by_main_content_dom(dom)
    dom_values = dom.to_h.values
    return dom if dom_values.any? { |dom_value| dom_value.include?('content') }
    dom.children.each do |child_dom|
      main_dom = self.find_by_main_content_dom(child_dom)
      return main_dom if main_dom.present?
    end
    return nil
  end
end
