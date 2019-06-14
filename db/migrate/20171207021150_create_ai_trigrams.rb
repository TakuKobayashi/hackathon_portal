class CreateAiTrigrams < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_trigrams do |t|
      t.integer :tweet_resource_id, null: false
      t.integer :position_genre, null: false, default: 0
      t.string :first_word, null: false, default: ''
      t.string :second_word, null: false, default: ''
      t.string :third_word, null: false, default: ''
    end
    add_index :ai_trigrams, :tweet_resource_id
    add_index :ai_trigrams, %i[first_word position_genre]
  end
end
