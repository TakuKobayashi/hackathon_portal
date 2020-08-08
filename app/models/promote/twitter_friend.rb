# == Schema Information
#
# Table name: promote_friends
#
#  id           :bigint           not null, primary key
#  type         :string(255)
#  from_user_id :string(255)      not null
#  to_user_id   :string(255)      not null
#  state        :integer          default("unrelated"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_promote_friends_on_created_at                   (created_at)
#  index_promote_friends_on_to_user_id_and_from_user_id  (to_user_id,from_user_id)
#
class Promote::TwitterFriend < Promote::Friend
end
