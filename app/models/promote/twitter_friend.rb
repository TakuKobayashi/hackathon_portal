# == Schema Information
#
# Table name: promote_friends
#
#  id                                :bigint           not null, primary key
#  type                              :string(255)
#  from_user_id                      :string(255)      not null
#  to_user_id                        :string(255)      not null
#  state                             :integer          default("unrelated"), not null
#  score                             :float(24)        default(0.0), not null
#  followed_at                       :datetime
#  record_followers_follower_counter :integer          default(0), not null
#
# Indexes
#
#  index_promote_friends_on_followed_at                  (followed_at)
#  index_promote_friends_on_score                        (score)
#  index_promote_friends_on_to_user_id_and_from_user_id  (to_user_id,from_user_id)
#
class Promote::TwitterFriend < Promote::Friend
  belongs_to :promote_user, class_name: 'Promote::TwitterUser', primary_key: 'user_id', foreign_key: 'to_user_id'

  def self.import_from_tweets!(me_user:, tweets: [], to_be_follower: false, default_score: 0)
    self.import_from_users!(me_user: me_user, twitter_users: tweets.map(&:user).uniq, to_be_follower: to_be_follower)
  end

  def self.import_from_users!(me_user:, twitter_users: [], to_be_follower: false, default_score: 0)
    to_user_id_twitter_friends =
      Promote::TwitterFriend.where(from_user_id: me_user.id, to_user_id: twitter_users.map { |tu| tu.id.to_s })
        .index_by(&:to_user_id)
    promote_twitter_friends = []
    twitter_users.each do |twitter_user|
      next if me_user.id.to_i == twitter_user.id.to_i
      promote_twitter_friend = to_user_id_twitter_friends[twitter_user.id.to_s]
      if promote_twitter_friend.blank?
        current_time = Time.current
        promote_twitter_friend =
          Promote::TwitterFriend.new(
            {
              id:
                (
                  # 現在時刻(マイクロ秒)をidとして記録
                  current_time.to_i * 1000000
                ) + current_time.usec,
              from_user_id: me_user.id,
              to_user_id: twitter_user.id,
              state: :unrelated,
              score: 0,
            },
          )
      end
      next if promote_twitter_friend.only_follower? && promote_twitter_friend.both_follow?
      promote_twitter_friend.build_be_follower if to_be_follower || twitter_user.following?
      if promote_twitter_friend.unrelated?
        # フォロワーのフォロワーですでにscoreが加算されているものは省く
        next if promote_twitter_friend.score > 0
        promote_twitter_friend.score = promote_twitter_friend.score + default_score
      end
      promote_twitter_friends << promote_twitter_friend
    end
    Promote::TwitterFriend.import!(promote_twitter_friends, on_duplicate_key_update: %i[state score])
  end

  def self.update_all_followers!(twitter_client:, user_id:)
    bot_user = twitter_client.user
    follower_id_cursors = twitter_client.follower_ids({ user_id: user_id.to_i, count: 5000 })
    retry_count = 0
    next_cursor = 0
    all_twitter_users = []
    begin
      next_cursor = follower_id_cursors.attrs[:next_cursor]
      follower_id_cursors.attrs[:ids].each_slice(Twitter::REST::Users::MAX_USERS_PER_REQUEST) do |user_ids|
        twitter_users = []
        begin
          twitter_users = twitter_client.users(user_ids.map(&:to_i))
          retry_count = 0
        rescue Twitter::Error::TooManyRequests => e
          Rails.logger.warn(
            [['TooManyRequest users Error:', e.rate_limit.reset_in.to_s, 's'].join, e.message].join('\n'),
          )
          sleep e.rate_limit.reset_in.to_i
          retry_count = retry_count + 1
          if retry_count < 5
            retry
          else
            return []
          end
        end
        Promote::TwitterUser.import_from_users!(twitter_users: twitter_users)
        # BotのフォロワーならBotのフォロワーとして、そうじゃない場合はフォロワーのフォロワーとして記録する
        if bot_user.id.to_s == user_id.to_s
          self.import_from_users!(
            me_user: bot_user, twitter_users: twitter_users, to_be_follower: true
          )
        else
          self.import_from_users!(
            me_user: bot_user, twitter_users: twitter_users, to_be_follower: false, default_score: Promote::FOLLOWERS_FOLLOWER_ADD_SCORE
          )
        end
        all_twitter_users += twitter_users
      end
      if next_cursor > 0
        begin
          follower_id_cursors.send(:fetch_next_page)
          retry_count = 0
        rescue Twitter::Error::TooManyRequests => e
          Rails.logger.warn(
            [['TooManyRequest follower fetch_next_page Error:', e.rate_limit.reset_in.to_s, 's'].join, e.message].join(
              '\n',
            ),
          )
          sleep e.rate_limit.reset_in.to_i
          retry_count = retry_count + 1
          if retry_count < 5
            retry
          else
            return []
          end
        end
      end
    end while next_cursor > 0
    return all_twitter_users
  end
end
