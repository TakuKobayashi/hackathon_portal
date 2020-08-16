class AddColumnToPromoteTables < ActiveRecord::Migration[6.0]
  def change
    add_column :promote_action_tweets, :lang, :string, null: false
    add_column :promote_friends, :record_followers_follower_counter, :integer, null: false, default: 0
  end
end
