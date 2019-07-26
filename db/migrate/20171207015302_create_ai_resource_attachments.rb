class CreateAiResourceAttachments < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_resource_attachments do |t|
      t.integer :tweet_resource_id, null: false
      t.integer :category, null: false, default: 0
      t.string :origin_src, null: false
      t.text :query
      t.text :options
    end
    add_index :ai_resource_attachments, %i[tweet_resource_id category], name: 'ai_resource_attachments_resource_and_category_index'
    add_index :ai_resource_attachments, :origin_src
  end
end
