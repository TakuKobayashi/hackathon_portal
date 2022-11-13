# == Schema Information
#
# Table name: blogger_bots
#
#  id              :bigint           not null, primary key
#  blogger_blog_id :string(255)      not null
#  blogger_post_id :string(255)      not null
#  title           :string(255)      not null
#  url             :string(255)      not null
#  date_number     :integer          not null
#  tag_names       :string(255)
#  event_ids       :text(65535)      not null
#  body            :text(16777215)   not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_blogger_bots_on_blogger_post_id_and_blogger_blog_id  (blogger_post_id,blogger_blog_id) UNIQUE
#  index_blogger_bots_on_date_number                          (date_number)
#

class BloggerBot < ApplicationRecord
  serialize :tag_names, JSON
  serialize :event_ids, JSON

  def self.remove_event!(
    event:,
    blogger_blog_url: 'https://hackathonportal.blogspot.com/',
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN')
  )
    service = GoogleServices.get_blogger_service(refresh_token: refresh_token)
    blogger_blog = service.get_blog_by_url(blogger_blog_url)
    date_number = event.started_at.year * 10000 + event.started_at.month
    blogger_bot = BloggerBot.find_by(date_number: date_number, blogger_blog_id: blogger_blog.id)
    if blogger_bot.present?
      blogger_bot.event_ids = blogger_bot.event_ids.select { |event_id| event_id != event.id }
      blogger_bot.save!
    end
  end

  def self.post_or_update_article!(
    events: [],
    blogger_blog_url: 'https://hackathonportal.blogspot.com/',
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN')
  )
    service = GoogleServices.get_blogger_service(refresh_token: refresh_token)
    blogger_blog = service.get_blog_by_url(blogger_blog_url)

    events_group = events.group_by { |e| e.started_at.year * 10000 + e.started_at.month }
    events_group.each do |date_number, event_arr|
      blogger_bot = BloggerBot.find_or_initialize_by(date_number: date_number, blogger_blog_id: blogger_blog.id)
      blogger_bot.event_ids = [blogger_bot.event_ids].flatten.compact | event_arr.map(&:id)
      blogger_bot.build_content
      blogger_bot.update_blogger!(google_api_service: service)
    end
  end

  def build_content
    post_events = Event.where(id: self.event_ids).includes(:event_detail).order('started_at ASC')
    start_month = date_number % 10000
    year_number = (date_number / 10000).to_i
    active_events, closed_events = post_events.partition { |event| event.active? }
    before_events, after_events = active_events.partition { |event| event.ended_at > Time.current }
    self.title = "#{year_number}年#{start_month}月のハッカソン開催情報まとめ!"
    self.body = BloggerBot.generate_html_body(events: post_events, year_number: year_number, start_month: start_month)
  end

  def self.generate_html_body(events:, year_number:, start_month:)
    active_events, closed_events = events.partition { |event| event.active? }
    before_events, after_events = active_events.partition { |event| event.ended_at > Time.current }
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, hard_wrap: true)
    render_lines = []
    render_lines << markdown.render("#{Time.current.strftime("%Y年%m月%d日 %H:%M")}更新")
    render_lines << markdown.render("#{year_number}年#{start_month}月のハッカソン・ゲームジャム・開発合宿の開催情報を定期的に紹介!!")
    render_lines << ""
    render_lines << markdown.render("# これから開催されるイベント")
    render_lines << ""

    before_events.each do |event|
      render_lines << BloggerBot.event_html_field(event: event)
    end

    if after_events.present?
      render_lines << markdown.render("---")
      render_lines << markdown.render("# すでに終了したイベント")
      after_events.each do |event|
        render_lines << BloggerBot.event_html_field(event: event)
      end
    end

    if closed_events.present?
      render_lines << markdown.render("---")
      render_lines << markdown.render("# 中止したイベント")
      closed_events.each do |event|
        render_lines << BloggerBot.event_html_field(event: event)
      end
    end
    return render_lines.join("<br>")
  end

  def self.event_html_field(event:)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, hard_wrap: true)
    html_arr = []
    html_arr << markdown.render("## [#{event.title}](#{event.url})")
    if event.active?
      html_arr << markdown.render(event.og_image_html.to_s)
    end
    html_arr << markdown.render("<span style=\"color: #0000FF;\">#{event.started_at.strftime('%Y年%m月%d日')}</span>")
    html_arr << markdown.render(event.place.to_s)
    if event.address.present? && event.lat.present? && event.lon.present?
      html_arr << markdown.render("[#{event.address}](#{event.generate_google_map_url})")
    end
    if event.lat.present? && event.lon.present?
      html_arr << markdown.render(event.generate_google_map_embed_tag)
    end
    if event.limit_number.present?
      html_arr << markdown.render("定員#{event.limit_number}人")
    end
    if event.attend_number >= 0
      if event.ended_at.present? && event.ended_at < Time.current
        html_arr << markdown.render("#{event.attend_number}人が参加しました")
      else
        html_arr << markdown.render("#{Time.current.strftime('%Y年%m月%d日 %H:%M')}現在 #{event.attend_number}人参加中")
        if event.limit_number.present?
          if (event.limit_number - event.attend_number) > 0
            html_arr << markdown.render("<span style=\"color: #FF0000;\">あと残り#{(event.limit_number - event.attend_number)}人</span> 参加可能")
          else
            html_arr << markdown.render("今だと補欠登録されると思います。<span style=\"color: #FF0000;\">(#{event.substitute_number}人が補欠登録中)</span>")
          end
        end
      end
    end
    return html_arr.join.html_safe
  end

  def update_blogger!(google_api_service:)
    blogger_post = Google::Apis::BloggerV3::Post.new
    blogger_post.id = self.blogger_post_id
    blogger_post.title = self.title
    blogger_post.content = self.body
    if self.new_record?
      result_blogger_post = google_api_service.insert_post(self.blogger_blog_id, blogger_post)
    else
      begin
        result_blogger_post = google_api_service.patch_post(self.blogger_blog_id, self.blogger_post_id, blogger_post)
      rescue Google::Apis::ClientError => e
        result_blogger_post = google_api_service.insert_post(self.blogger_blog_id, blogger_post)
      end
    end
    self.update!(
      {
        blogger_post_id: result_blogger_post.id,
        title: result_blogger_post.title,
        url: result_blogger_post.url,
        body: result_blogger_post.content,
        tag_names: result_blogger_post.labels,
      },
    )
  end
end
