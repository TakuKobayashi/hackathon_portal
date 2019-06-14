class CreateQiitaBots < ActiveRecord::Migration[5.0]
  def change
    create_table :qiita_bots do |t|
      t.string :qiita_id, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.integer :season_number, null: false
      t.string :tag_names
      t.text :event_ids, null: false
      t.text :body, null: false, limit: 16_777_215
      t.text :rendered_body, limit: 16_777_215
      t.timestamps
    end
    add_index :qiita_bots, :qiita_id, unique: true
    add_index :qiita_bots, :season_number
  end
end
