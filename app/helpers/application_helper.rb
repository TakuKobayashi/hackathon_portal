module ApplicationHelper
  def event_blogger_html_field(event)
    html_arr = []
    html_arr << content_tag("h3", link_to(event.title, event.url))
    if event.active?
      html_arr << content_tag("div", event.og_image_html)
      html_arr << "<br>"
    end
    html_arr << content_tag("div", event.started_at.strftime("%Y年%m月%d日"), {style: "color: #0000FF;"})
    html_arr << content_tag("div", event.place.to_s)
    if event.address.present? && event.lat.present? && event.lon.present?
      html_arr << content_tag("div", link_to(event.address, event.generate_google_map_url))
    end
    if event.lat.present? && event.lon.present?
      html_arr << content_tag("div", event.generate_google_map_embed_tag)
    end
    if event.limit_number.present?
      html_arr << content_tag("div", "定員#{event.limit_number}人")
    end
    if event.attend_number >= 0
      if event.ended_at.present? && event.ended_at < Time.current
        html_arr << content_tag("div", "#{event.attend_number}人が参加しました")
      else
        html_arr << content_tag("div", "#{Time.now.strftime("%Y年%m月%d日 %H:%M")}現在 #{event.attend_number}人参加中")
        if event.limit_number.present?
          if (event.limit_number - event.attend_number) > 0
            arr = [content_tag("div", "あと残り#{(event.limit_number - event.attend_number)}人", {style: "color: #FF0000;"})]
            arr << "参加可能"
            html_arr << arr.join(" ")
          else
            html_arr << content_tag("div", "今だと補欠登録されると思います。<span style=\"color: #FF0000;\">(#{event.substitute_number}人が補欠登録中)</span>")
          end
        end
      end
    end
    return html_arr.join.html_safe
  end
end
