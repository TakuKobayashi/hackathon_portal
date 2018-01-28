class CreateAiHashtags < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_hashtags do |t|
      t.string :hashtag, null: false
    end
    add_index :ai_hashtags, :hashtag
  end
end
