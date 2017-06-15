class CreateQiitaBots < ActiveRecord::Migration[5.0]
  def change
    create_table :qiita_bots do |t|
      t.string :qiita_id, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.string :tags_csv
      t.text :event_ids, null: false
      t.text :body, null: false
      t.text :rendered_body
      t.datetime :qiita_updated_at, null: false
      t.timestamps
    end
    add_index :qiita_bots, :qiita_id, unique: true
    add_index :qiita_bots, :qiita_updated_at
  end
end
