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
#  event_type    :string(255)
#
# Indexes
#
#  index_qiita_bots_on_qiita_id       (qiita_id) UNIQUE
#  index_qiita_bots_on_season_number  (season_number)
#

class QiitaBot < ApplicationRecord
  serialize :tag_names, JSON
  serialize :event_ids, JSON

  def generate_post_send_params(year_number:, start_month:,end_month:)
    qiita_events = Event.where(id: qiita_bot.event_ids).order('started_at ASC')
    before_events_from_qiita, after_events_from_qiita = qiita_events.partition do |e|
      e.ended_at.present? ? e.ended_at > Time.current : (e.started_at + 2.day) > Time.current
    end
    body = "#{Time.current.strftime('%Y年%m月%d日 %H:%M')}更新\n"
    body +=
      "#{year_number}年#{start_month}月〜#{year_number}年#{
        end_month
      }月のハッカソン・ゲームジャム・開発合宿の開催情報を定期的に紹介!!\n※こちらは自動的に集めたものになります。\n"
    body += "# これから開催されるイベント\n\n"
    body += before_events_from_qiita.map(&:generate_qiita_cell_text).join("\n\n")
    if after_events_from_qiita.present?
      body += "\n\n---------------------------------------\n\n"
      body += "# すでに終了したイベント\n\n"
      body += after_events_from_qiita.map(&:generate_qiita_cell_text).join("\n\n")
    end
    send_params = {
      title: "#{year_number}年#{start_month}月〜#{year_number}年#{end_month}月のハッカソン開催情報まとめ!",
      body: body,
      tags: [{ name: 'hackathon' }, { name: 'ハッカソン' }, { name: 'アイディアソン' }, { name: '合宿' }, { name: year_number.to_s }]
    }
    return send_params
  end

  def self.post_or_update_article!(events: [], access_token: ENV.fetch('QIITA_BOT_ACCESS_TOKEN', ''))
    client = self.get_qiita_client(access_token: access_token)
    events_group = events.group_by(&:season_date_number)
    events_group.each do |date_number, event_arr|
      qiita_bot = QiitaBot.find_or_initialize_by(season_number: date_number)
      qiita_bot.event_ids = [qiita_bot.event_ids].flatten.compact | event_arr.map(&:id)
      month_range = date_number % 10000
      year_number = (date_number / 10000).to_i
      start_month = (month_range / 100).to_i
      end_month = (month_range % 100).to_i
      send_params = qiita_bot.generate_post_send_params(year_number: year_number, start_month: start_month, end_month: end_month)
      if qiita_bot.new_record?
        response = client.create_item(send_params).body
      else
        response = client.update_item(qiita_bot.qiita_id, send_params).body
      end
      qiita_bot.qiita_id = response['id'] if qiita_bot.qiita_id.blank?
      response_tags = response['tags'] || []
      if response['title'].present? && response['url'].present?
        qiita_bot.update!(
          {
            title: response['title'],
            url: response['url'],
            body: response['body'],
            rendered_body: response['raw_body'],
            tag_names: response_tags.map { |t| t['name'] }
          }
        )
      else
        logger = ActiveSupport::Logger.new('log/bot_error.log')
        console = ActiveSupport::Logger.new(STDOUT)
        logger.extend ActiveSupport::Logger.broadcast(console)
        message = { qiita_bot: qiita_bot.attributes, qiita_response: response, will_sendparams: send_params }.to_json
        logger.info(message)
      end
    end
  end

  private
  def self.get_qiita_client(access_token: ENV.fetch('QIITA_BOT_ACCESS_TOKEN', ''))
    client = Qiita::Client.new(access_token: access_token)
    return client
  end
end
