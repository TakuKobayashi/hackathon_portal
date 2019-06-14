class CreateLogCrawls < ActiveRecord::Migration[5.1]
  def change
    create_table :log_crawls do |t|
      t.string :from_type, null: false
      t.integer :from_id, null: false
      t.datetime :crawled_at, null: false
      t.timestamps
    end
    add_index :log_crawls, :crawled_at
    add_index :log_crawls, %i[from_type from_id]
  end
end
