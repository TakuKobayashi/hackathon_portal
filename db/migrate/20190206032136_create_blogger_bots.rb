class CreateBloggerBots < ActiveRecord::Migration[5.2]
  def change
    create_table :blogger_bots do |t|
      t.string :blogger_blog_id, null: false
      t.string :blogger_post_id, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.integer :date_number, null: false
      t.string :tag_names
      t.string :event_type
      t.text :event_ids, null: false
      t.text :body, null: false, limit: 16_777_215
      t.timestamps
    end
    add_index :blogger_bots, %i[blogger_post_id blogger_blog_id], unique: true
    add_index :blogger_bots, :date_number
  end
end
