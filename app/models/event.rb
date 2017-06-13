# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime         not null
#  limit_number      :integer
#  address           :string(255)      not null
#  place             :string(255)      not null
#  lat               :float(24)
#  lon               :float(24)
#  cost              :integer          default(0), not null
#  max_prize         :integer          default(0), not null
#  currency_unit     :string(255)      default("円"), not null
#  owner_id          :string(255)
#  owner_nickname    :string(255)
#  owner_name        :string(255)
#  attend_number     :integer          default(0), not null
#  substitute_number :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type) UNIQUE
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#

class Event < ApplicationRecord
  HACKATHON_KEYWORDS = ["hackathon", "ハッカソン", "jam", "ジャム", "アイディアソン", "アイデアソン", "ideathon"]

  def self.import_events!
    Connpass.import_events!
    Doorkeeper.import_events!
  end

  def generate_tweet_text
     tweet_words = [self.title, self.url, self.started_at.strftime("%Y年%m月%d日")]
     tweet_words += ["#hackathon"]
     text_size = 0
     tweet_words.select! do |text|
       text_size += text.size
       text_size <= 140
     end
     return tweet_words.join("\n")
  end
end
