class CreateTwitterBots < ActiveRecord::Migration[5.0]
  def change
    create_table :twitter_bots do |t|
      t.string :tweet, null: false
      t.string :tweet_id, null: false
      t.string :from_type
      t.integer :from_id
      t.datetime :tweet_time, null: false
      t.timestamps
    end
    add_index :twitter_bots, :tweet_id
    add_index :twitter_bots, [:from_type, :from_id]
  end
end
