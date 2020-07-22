# == Schema Information
#
# Table name: events
#
#  id                :integer          not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  shortener_url     :string(255)
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime
#  limit_number      :integer
#  address           :string(255)
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
#  informed_from     :integer          default("web"), not null
#  state             :integer          default("active"), not null
#
# Indexes
#
#  index_events_on_event_id_and_type        (event_id,type)
#  index_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_events_on_title                    (title)
#  index_events_on_url                      (url)
#

class HackathonEvent < Event
  HACKATHON_KEYWORDS = %w[hackathon ッカソン jam ジャム アイディアソン アイデアソン ideathon 合宿]
  DEVELOPMENT_CAMP_KEYWORDS = %w[開発 プログラム プログラミング ハンズオン 勉強会 エンジニア デザイナ デザイン ゲーム]
  HACKATHON_CHECK_SEARCH_KEYWORD_POINTS = {
    'hackathon' => 2,
    'ハッカソン' => 2,
    'hack day' => 2,
    'アイディアソン' => 2,
    'アイデアソン' => 2,
    'ideathon' => 2,
    'ゲームジャム' => 2,
    'gamejam' => 2,
    'game jam' => 2,
    '合宿' => 2,
    'ハック' => 1
  }

  HACKATHON_KEYWORD_CALENDER_INDEX = {
    'hackathon' => 1,
    'ハッカソン' => 1,
    'hack day' => 1,
    'アイディアソン' => 2,
    'アイデアソン' => 2,
    'ideathon' => 2,
    'ゲームジャム' => 3,
    'gamejam' => 3,
    'game jam' => 3,
    '合宿' => 4,
    'ハック' => 1
  }

  def default_hashtags
    return %w[#hackathon #ハッカソン]
  end
end
