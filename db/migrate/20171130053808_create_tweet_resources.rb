class CreateTweetResources < ActiveRecord::Migration[5.1]
  def change
    create_table :tweet_resources do |t|
      t.string :type
      t.string :resource_id, null: false
      t.string :resource_user_id
      t.string :resource_user_name
      t.text :body, null: false
      t.text :url
      t.string :hash_tag
      t.datetime :published_at, null: false
      t.text :options
    end
    add_index :tweet_resources, [:resource_id, :type], unique: true
    add_index :tweet_resources, :published_at
    add_index :tweet_resources, :hash_tag
  end
end
