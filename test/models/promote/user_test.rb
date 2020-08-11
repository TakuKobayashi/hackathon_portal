# == Schema Information
#
# Table name: promote_users
#
#  id             :bigint           not null, primary key
#  user_id        :string(255)      not null
#  type           :string(255)
#  screen_name    :string(255)      not null
#  state          :integer          default("unrelated"), not null
#  follower_count :integer          default(0), not null
#  follow_count   :integer          default(0), not null
#
# Indexes
#
#  index_promote_users_on_user_id_and_type  (user_id,type) UNIQUE
#
require 'test_helper'

class Promote::UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
