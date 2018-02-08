class CreateAiTweetResources < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_tweet_resources do |t|
      t.string :type
      t.string :resource_id, null: false
      t.string :resource_user_id
      t.string :resource_user_name
      t.text :body, null: false
      t.string :mention_user_name
      t.string :reply_id
      t.string :quote_id
      t.datetime :published_at, null: false
      t.text :options
    end
    add_index :ai_tweet_resources, [:resource_id, :type], unique: true
    add_index :ai_tweet_resources, :published_at
  end
end
