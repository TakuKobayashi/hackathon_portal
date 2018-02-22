# == Schema Information
#
# Table name: qiita_bots
#
#  id            :integer          not null, primary key
#  qiita_id      :string(255)      not null
#  title         :string(255)      not null
#  url           :string(255)      not null
#  season_number :integer          not null
#  tag_names     :string(255)
#  event_ids     :text(65535)      not null
#  body          :text(16777215)   not null
#  rendered_body :text(16777215)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_qiita_bots_on_qiita_id       (qiita_id) UNIQUE
#  index_qiita_bots_on_season_number  (season_number)
#

class QiitaBot < ApplicationRecord
  serialize :tag_names, JSON
  serialize :event_ids, JSON

  def self.post_or_update_article!(events: [])
    client = get_qiita_client
    events_group = events.group_by{|e| e.season_date_number }
    events_group.each do |date_number, event_arr|
      qiita_bot = QiitaBot.find_or_initialize_by(season_number: date_number)
      qiita_bot.event_ids = [qiita_bot.event_ids].flatten.compact | event_arr.map(&:id)
      before_events_from_qiita, after_events_from_qiita = Event.where(id: qiita_bot.event_ids).order("started_at ASC").partition do |e|
        if e.ended_at.present?
          e.ended_at > Time.current
        else
          (e.started_at + 2.day) > Time.current
        end
      end

      month_range = date_number % 10000
      year_number = (date_number / 10000).to_i
      start_month = (month_range / 100).to_i
      end_month = (month_range % 100).to_i
      body = "#{Time.current.strftime("%Y年%m月%d日 %H:%M")}更新\n"
      body += "#{year_number}年#{start_month}月〜#{year_number}年#{end_month}月のハッカソン・ゲームジャム・開発合宿の開催情報を定期的に紹介!!\n※こちらは自動的に集めたものになります。\n"
      body += "# これから開催されるイベント\n\n"
      body += before_events_from_qiita.map{|event| event.generate_qiita_cell_text }.join("\n\n")
      if after_events_from_qiita.present?
        body += "\n\n---------------------------------------\n\n"
        body += "# すでに終了したイベント\n\n"
        body += after_events_from_qiita.map{|event| event.generate_qiita_cell_text }.join("\n\n")
      end
      send_params = {
        title: "#{year_number}年#{start_month}月〜#{year_number}年#{end_month}月のハッカソン開催情報まとめ!",
        body: body,
        tags: [
          {
            name: "hackathon",
          },
          {
            name: "ハッカソン",
          },
          {
            name: "アイディアソン",
          },
          {
            name: "合宿",
          },
          {
            name: year_number.to_s,
          }
        ]
      }

      if qiita_bot.new_record?
        response = client.create_item(send_params).body
      else
        response = client.update_item(qiita_bot.qiita_id, send_params).body
      end
      qiita_bot.qiita_id = response["id"] if qiita_bot.qiita_id.blank?
      response_tags = response["tags"] || []
      qiita_bot.update!({
        title: response["title"],
        url: response["url"],
        body: response["body"],
        rendered_body: response["raw_body"],
        tag_names: response_tags.map{|t| t["name"] }
      })
    end
  end

  private
  def self.get_qiita_client
    client = Qiita::Client.new(access_token: ENV.fetch('QIITA_BOT_ACCESS_TOKEN', ''))
    return client
  end
end
