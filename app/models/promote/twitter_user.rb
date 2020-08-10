# == Schema Information
#
# Table name: promote_users
#
#  id             :bigint           not null, primary key
#  type           :string(255)
#  user_id        :string(255)      not null
#  screen_name    :string(255)      not null
#  state          :integer          default("unrelated"), not null
#  follower_count :integer          default(0), not null
#  follow_count   :integer          default(0), not null
#
# Indexes
#
#  index_promote_users_on_user_id  (user_id)
#
class Promote::TwitterUser < Promote::User
end
