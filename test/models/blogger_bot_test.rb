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

require 'test_helper'

class BloggerBotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
