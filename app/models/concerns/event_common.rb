module EventCommon
  def generate_qiita_cell_text
    words = [
      "### [#{self.title}](#{self.url})",
    ]
    image_url = self.get_og_image_url
    if image_url.present?
      fi = FastImage.new(image_url.to_s)
      width, height = fi.size
      size_text = AdjustImage.calc_resize_text(width: width, height: height, max_length: 300)
      resize_width, resize_height = size_text.split("x")
      words << (ActionController::Base.helpers.image_tag(image_url, {width: resize_width, height: resize_height, alt: self.title}) + "\n")
    end

    words += [
      self.started_at.strftime("%Y年%m月%d日"),
      self.place,
      "[#{self.address}](#{self.generate_google_map_url})"
    ]
    if self.limit_number.present?
      words << "定員#{self.limit_number}人"
    end
    if self.type == "Atnd" || self.type == "Connpass" || self.type == "Doorkeeper"
      if self.ended_at.present? && self.ended_at < Time.current
        words << "#{self.attend_number}人が参加しました"
      else
        words << "#{Time.now.strftime("%Y年%m月%d日 %H:%M")}現在 #{self.attend_number}人参加中"
        if self.limit_number.present?
          remain_number = self.limit_number - self.attend_number
          if remain_number > 0
            words << "<font color=\"#FF0000;\">あと残り#{remain_number}人</font> 参加可能"
          else
            words << "今だと補欠登録されると思います。<font color=\"#FF0000\">(#{self.substitute_number}人が補欠登録中)</font>"
          end
        end
      end
    end
    return words.join("\n")
  end
end