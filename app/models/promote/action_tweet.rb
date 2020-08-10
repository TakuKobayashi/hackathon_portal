# == Schema Information
#
# Table name: promote_action_tweets
#
#  id                   :bigint           not null, primary key
#  user_id              :string(255)      not null
#  status_user_id       :string(255)      not null
#  status_user_nickname :string(255)      not null
#  status_id            :string(255)      not null
#  state                :integer          default("unrelated"), not null
#  is_liked             :boolean          default(FALSE), not null
#  is_retweeted         :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_promote_action_tweets_on_status_id       (status_id)
#  index_promote_action_tweets_on_status_user_id  (status_user_id)
#  index_promote_action_tweets_on_user_id         (user_id)
#
class Promote::ActionTweet < ApplicationRecord
  enum state: { unrelated: 0, only_liked: 1, only_retweeted: 10, liked_and_retweet: 11 }
end
