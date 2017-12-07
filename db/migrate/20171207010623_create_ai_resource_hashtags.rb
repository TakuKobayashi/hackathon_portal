class CreateAiResourceHashtags < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_resource_hashtags do |t|
      t.string :resource_type, null: false
      t.integer :resource_id, null: false
      t.integer :hashtag_id, null: false
    end

    add_index :ai_resource_hashtags, [:resource_type, :resource_id, :hashtag_id], unique: true, name: "ai_resource_hashtags_unique_index"
    add_index :ai_resource_hashtags, :hashtag_id
  end
end
