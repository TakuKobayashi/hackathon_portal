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
class Promote::User < ApplicationRecord
  enum state: { unrelated: 0, only_follow: 1, only_follower: 2, both_follow: 3 }
end
