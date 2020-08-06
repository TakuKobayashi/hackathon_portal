class CreatePromoteActionTweets < ActiveRecord::Migration[6.0]
  def change
    create_table :promote_action_tweets do |t|
      t.string :user_id, null: false
      t.string :status_user_id, null: false
      t.string :status_user_nickname, null: false
      t.string :status_id, null: false
      t.integer :state, null: false, default: 0
      t.boolean :is_liked, null: false, default: false
      t.boolean :is_retweeted, null: false, default: false
      t.timestamps
    end
    add_index :promote_action_tweets, :user_id
    add_index :promote_action_tweets, :status_user_id
    add_index :promote_action_tweets, :status_id
  end
end
