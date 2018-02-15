# == Schema Information
#
# Table name: log_crawls
#
#  id         :integer          not null, primary key
#  from_type  :string(255)      not null
#  from_id    :integer          not null
#  crawled_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_log_crawls_on_crawled_at             (crawled_at)
#  index_log_crawls_on_from_type_and_from_id  (from_type,from_id)
#

class Log::Crawl < ApplicationRecord
  belongs_to :from, polymorphic: true, required: false
end
