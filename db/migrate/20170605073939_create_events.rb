class CreateEvents < ActiveRecord::Migration[5.0]
  def change
    create_table :events do |t|
      t.string :event_id
      t.string :type
      t.string :title, null: false
      t.string :url, null: false
      t.text :description
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: false
      t.integer :limit_number
      t.string :address, null: false
      t.string :place, null: false
      t.float :lat
      t.float :lon
      t.integer :cost, null: false, default: 0
      t.integer :max_prize, null: false, default: 0
      t.string :currency_unit, null: false, default: "円"
      t.string :owner_id
      t.string :owner_nickname
      t.string :owner_name
      t.integer :attend_number, null: false, default: 0
      t.integer :substitute_number, null: false, default: 0
      t.timestamps
    end
    add_index :events, [:event_id, :type], unique: true
    add_index :events, [:started_at, :ended_at]
    add_index :events, :title
  end
end
