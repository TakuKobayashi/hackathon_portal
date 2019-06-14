class CreateCustomCrawlTargets < ActiveRecord::Migration[5.0]
  def change
    create_table :custom_crawl_targets do |t|
      t.integer :parse_genre, null: false, default: 0
      t.string :title, null: false, default: ''
      t.string :root_url, null: false
      t.string :path
      t.text :query_hash
      t.integer :max_crawl_loop_count
      t.boolean :activate, null: false, default: true
      t.text :filter_words
      t.text :correspond_column_filter_json
      t.integer :loop_counter, null: false, default: 0
      t.datetime :last_crawled_at
      t.integer :crawled_counter, null: false, default: 0
      t.timestamps
    end
    add_index :custom_crawl_targets, :root_url
  end
end
