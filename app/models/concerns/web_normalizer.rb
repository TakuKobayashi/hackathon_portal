module WebNormalizer
  def self.merge_full_url(src:, org:)
    src_url = Addressable::URI.parse(src.to_s)
    if src_url.scheme.blank?
      org_url = Addressable::URI.parse(org.to_s)
      full_url = ""
      if src_url.to_s.start_with?('//')
        full_url = org_url.scheme + ':' + src_url.to_s
      elsif src_url.to_s.start_with?('/')
        full_url = org_url.scheme + '://' + org_url.host + src_url.to_s
      elsif src_url.to_s.start_with?('./')
        pathname = Pathname.new(org_url.to_s)
        full_url = pathname.join(src_url.to_s).to_s
      elsif src_url.to_s.start_with?('../')
        pathname = Pathname.new(org_url.to_s)
        full_url = pathname.join(src_url.to_s).to_s
      else
        full_url = org_url.to_s + src_url.to_s;
      end
      return full_url
    else
      return src_url.to_s
    end
  end
end