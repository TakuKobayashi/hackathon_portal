class CreatePromoteActionTweets < ActiveRecord::Migration[6.0]
  def change
    create_table :promote_action_tweets do |t|
      t.string :user_id, null: false
      t.string :status_user_id, null: false
      t.string :status_user_name, null: false
      t.string :status_id, null: false
      t.integer :state, null: false, default: 0
      t.float :score, null: false, default: 0
      t.datetime :created_at, null: false
    end
    add_index :promote_action_tweets, :user_id
    add_index :promote_action_tweets, :status_user_id
    add_index :promote_action_tweets, :status_id
    add_index :promote_action_tweets, :created_at
  end
end
