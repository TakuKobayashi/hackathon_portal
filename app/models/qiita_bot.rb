# == Schema Information
#
# Table name: qiita_bots
#
#  id               :integer          not null, primary key
#  qiita_id         :string(255)      not null
#  title            :string(255)      not null
#  url              :string(255)      not null
#  tags_csv         :string(255)
#  event_ids        :text(65535)      not null
#  body             :text(65535)      not null
#  rendered_body    :text(65535)
#  qiita_updated_at :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_qiita_bots_on_qiita_id          (qiita_id) UNIQUE
#  index_qiita_bots_on_qiita_updated_at  (qiita_updated_at)
#

class QiitaBot < ApplicationRecord
end
