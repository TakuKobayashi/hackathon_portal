# == Schema Information
#
# Table name: scaling_unity_events
#
#  id                :bigint           not null, primary key
#  event_id          :string(255)
#  type              :string(255)
#  title             :string(255)      not null
#  url               :string(255)      not null
#  shortener_url     :string(255)
#  description       :text(65535)
#  started_at        :datetime         not null
#  ended_at          :datetime
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
#  judge_state       :integer          default("before_judge"), not null
#
# Indexes
#
#  index_scaling_unity_events_on_event_id_and_type        (event_id,type)
#  index_scaling_unity_events_on_started_at_and_ended_at  (started_at,ended_at)
#  index_scaling_unity_events_on_title                    (title)
#  index_scaling_unity_events_on_url                      (url)
#

class Scaling::UnityEvent < ApplicationRecord
  include EventCommon

  enum judge_state: { before_judge: 0, maybe_unity: 1, another_development_event: 2, unknown: 9 }

  has_many :summaries, as: :resource, class_name: 'Ai::ResourceSummary'
  has_many :resource_hashtags, as: :resource, class_name: 'Ai::ResourceHashtag'
  has_many :hashtags, through: :resource_hashtags, source: :hashtag
  accepts_nested_attributes_for :hashtags

  UNITY_KEYWORDS = %w[unity Unity ユニティ XR AR VR]

  def self.import_events!
    # マルチスレッドで処理を実行するとCircular dependency detected while autoloading constantというエラーが出るのでその回避のためあらかじめeager_loadする
    Rails.application.eager_load!
    event_classes = [
      Scaling::ConnpassUnityEvent,
      Scaling::DoorkeeperUnityEvent,
      Scaling::AtndUnityEvent,
      Scaling::PeatixUnityEvent,
      Scaling::MeetupUnityEvent
    ]
    Parallel.each(event_classes, in_threads: event_classes.size, &:import_events!)
  end

  def self.google_form_spreadsheet_id
    return '1KbKcNoUXThP5pMz_jDne7Mcvl1aFdUHeV9cDNI1OUfY'
  end
end
