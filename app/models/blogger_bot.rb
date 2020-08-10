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
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', '')
  )
    service = GoogleServices.get_blogger_service(refresh_token: refresh_token)
    blogger_blog = service.get_blog_by_url(blogger_blog_url)
    date_number = event.started_at.year * 10000 + event.started_at.month
    blogger_bot = BloggerBot.find_by(date_number: date_number, blogger_blog_id: blogger_blog.id)
    blogger_bot.event_ids = blogger_bot.event_ids.select { |event_id| event_id != event.id }
    blogger_bot.save!
  end

  def self.post_or_update_article!(
    events: [],
    blogger_blog_url: 'https://hackathonportal.blogspot.com/',
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', '')
  )
    context = ActionView::LookupContext.new(Rails.root.join('app', 'views'))
    action_view_renderer = ActionView::Base.new(context)
    service = GoogleServices.get_blogger_service(refresh_token: refresh_token)
    blogger_blog = service.get_blog_by_url(blogger_blog_url)

    events_group = events.group_by { |e| e.started_at.year * 10000 + e.started_at.month }
    events_group.each do |date_number, event_arr|
      blogger_bot = BloggerBot.find_or_initialize_by(date_number: date_number, blogger_blog_id: blogger_blog.id)
      blogger_bot.event_ids = [blogger_bot.event_ids].flatten.compact | event_arr.map(&:id)
      blogger_bot.build_content(action_view_renderer: action_view_renderer)
      blogger_bot.update_blogger!(google_api_service: service)
    end
  end

  def build_content(action_view_renderer:)
    post_events = Event.where(id: self.event_ids).order('started_at ASC')
    start_month = date_number % 10000
    year_number = (date_number / 10000).to_i
    active_events, closed_events = post_events.partition { |event| event.active? }
    before_events, after_events =
      active_events.partition do |event|
        event.ended_at.present? ? event.ended_at > Time.current : (event.started_at + 2.day) > Time.current
      end
    self.title = "#{year_number}年#{start_month}月のハッカソン開催情報まとめ!"
    self.body =
      action_view_renderer.render(
        template: 'blogger/publish',
        format: 'html',
        locals: {
          before_events: before_events,
          after_events: after_events,
          closed_events: closed_events,
          year_number: year_number,
          start_month: start_month,
        },
      )
  end

  def update_blogger!(google_api_service:)
    blogger_post = Google::Apis::BloggerV3::Post.new
    blogger_post.id = self.blogger_post_id
    blogger_post.title = self.title
    blogger_post.content = self.body
    if self.new_record?
      result_blogger_post = google_api_service.insert_post(self.blogger_blog_id, blogger_post)
    else
      result_blogger_post = google_api_service.patch_post(self.blogger_blog_id, self.blogger_post_id, blogger_post)
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
