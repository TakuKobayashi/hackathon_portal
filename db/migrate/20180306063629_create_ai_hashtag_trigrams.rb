class CreateAiHashtagTrigrams < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_hashtag_trigrams do |t|
      t.integer :trigram_id, null: false
      t.integer :hashtag_id, null: false
    end
    add_index :ai_hashtag_trigrams, :trigram_id
    add_index :ai_hashtag_trigrams, :hashtag_id
  end
end
