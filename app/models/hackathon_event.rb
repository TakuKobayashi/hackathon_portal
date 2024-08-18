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
#  started_at        :datetime         not null
#  ended_at          :datetime         not null
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
#  informed_from     :integer          default("web"), not null
#  state             :integer          default("active"), not null
#
# Indexes
#
#  index_events_on_ended_at                    (ended_at)
#  index_events_on_event_id_and_informed_from  (event_id,informed_from)
#  index_events_on_started_at                  (started_at)
#  index_events_on_url                         (url)
#

class HackathonEvent < Event
  SEARCH_OPERATION_KEYWORDS = {
    EventbriteOperation => %w[hackathon ideathon gamejam],
    DevpostOperation => %w[],
    ItchIoOperation => %w[],
    #ConnpassOperation => %w[hackathon ッカソン はっかそん jam ジャム アイディアソン アイデアソン ideathon 合宿],
    DoorkeeperOperation => %w[hackathon ッカソン はっかそん jam ジャム アイディアソン アイデアソン ideathon 合宿],
    PeatixOperation => %w[hackathon ハッカソン ゲームジャム gamejam アイディアソン アイデアソン ideathon 開発合宿],
  }
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
    'ハック' => 1,
  }

  def self.google_form_spreadsheet_id
    return '1KbKcNoUXThP5pMz_jDne7Mcvl1aFdUHeV9cDNI1OUfY'
  end

  def default_hashtags
    return %w[#hackathon #ハッカソン]
  end
end
