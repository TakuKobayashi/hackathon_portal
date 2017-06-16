# == Schema Information
#
# Table name: qiita_bots
#
#  id             :integer          not null, primary key
#  qiita_id       :string(255)      not null
#  title          :string(255)      not null
#  url            :string(255)      not null
#  term_range_min :datetime         not null
#  term_range_max :datetime         not null
#  tag_names      :string(255)
#  event_ids      :text(65535)      not null
#  body           :text(65535)      not null
#  rendered_body  :text(65535)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_qiita_bots_on_qiita_id                           (qiita_id) UNIQUE
#  index_qiita_bots_on_term_range_min_and_term_range_max  (term_range_min,term_range_max)
#

class QiitaBot < ApplicationRecord
  serialize :tag_names, JSON
  serialize :event_ids, JSON

  GROOP_MONTH = 3

  def self.post_or_update_article!(events: [])
    client = get_qiita_client
    events_arr = groop_by_events_by_three_month(events: events)
    events_arr.each do |events|
      body = "#{Time.current.strftime("%Y年%m月%d日 %H:%M")}更新\n"
      body += "ハッカソンの開催情報を定期的に紹介!!\n※こちらは自動的に集めたもののご紹介になります。\n"
      body += events.map{|event| event.generate_qiita_cell_text }.join("\n\n")
      send_params = {
        title: "ハッカソン開催情報まとめ!(自動収集版)",
        body: body,
        tags: [
          {
            name: "hackathon",
          }
        ]
      }
      response = client.create_item(send_params).body
      bot = QiitaBot.find_or_initialize_by(qiita_id: response["id"])
      bot.update!({
        title: response["title"],
        url: response["url"],
        body: response["body"], 
        rendered_body: response["raw_body"],
        event_ids: events.map(&:id),
        tag_names: response["tags"].map{|t| t["name"] },
        qiita_updated_at: response["updated_at"]
      })
    end
  end

  def self.groop_by_events_by_month(events: [])
    events_groop = events.groop_by{|e| [e.started_at.year, e.started_at.month / GROOP_MONTH] }
    return events_groop.values
  end

  private
  def self.get_qiita_client
    apiconfig = YAML.load(File.open(Rails.root.to_s + "/config/apiconfig.yml"))
    client = Qiita::Client.new(access_token: apiconfig["qiita"]["access_token"])
    return client
  end
end
