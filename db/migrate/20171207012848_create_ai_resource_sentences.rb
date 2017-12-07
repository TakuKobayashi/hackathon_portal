class CreateAiResourceSentences < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_resource_sentences do |t|
      t.integer :tweet_resource_id, null: false
      t.text :body, null: false
    end
    add_index :ai_resource_sentences, [:tweet_resource_id]
  end
end
