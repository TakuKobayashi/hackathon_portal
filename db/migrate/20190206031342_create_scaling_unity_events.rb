class CreateScalingUnityEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :scaling_unity_events do |t|
      t.string :event_id
      t.string :type
      t.string :title, null: false
      t.string :url, null: false
      t.string :shortener_url
      t.text :description
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :limit_number
      t.string :address, null: false
      t.string :place, null: false
      t.float :lat
      t.float :lon
      t.integer :cost, null: false, default: 0
      t.integer :max_prize, null: false, default: 0
      t.string :currency_unit, null: false, default: '円'
      t.string :owner_id
      t.string :owner_nickname
      t.string :owner_name
      t.integer :attend_number, null: false, default: 0
      t.integer :substitute_number, null: false, default: 0
      t.binary :location_image_binary, limit: 1_600.kilobyte
      t.timestamps
    end
    add_index :scaling_unity_events, %i[event_id type], unique: true
    add_index :scaling_unity_events, %i[started_at ended_at]
    add_index :scaling_unity_events, :title
  end
end
