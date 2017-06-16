class CreateQiitaBots < ActiveRecord::Migration[5.0]
  def change
    create_table :qiita_bots do |t|
      t.string :qiita_id, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.datetime :term_range_min, null: false
      t.datetime :term_range_max, null: false
      t.string :tag_names
      t.text :event_ids, null: false
      t.text :body, null: false
      t.text :rendered_body
      t.timestamps
    end
    add_index :qiita_bots, :qiita_id, unique: true
    add_index :qiita_bots, [:term_range_min, :term_range_max]
  end
end
