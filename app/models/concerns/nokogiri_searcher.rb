module NokogiriSearcher
  def self.find_by_main_content_dom(dom)
    dom_values = dom.to_h.values
    if dom_values.any?{|dom_value| dom_value.include?("content") }
      return dom
    end
    dom.children.each do |child_dom|
      main_dom = self.find_by_main_content_dom(child_dom)
      if main_dom.present?
        return main_dom
      end
    end
    return nil
  end
end