class CreateAiAppearWords < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_appear_words do |t|
      t.string :word, null: false
      t.string :part, null: false
      t.string :reading, null: false
      t.integer :appear_count, null: false, default: 0
      t.integer :sentence_count, null: false, default: 0
    end
    add_index :ai_appear_words, [:word, :part], unique: true
    add_index :ai_appear_words, :reading
  end
end
