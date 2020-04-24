class IntegrateEventsTable < ActiveRecord::Migration[6.0]
  def up
    Event.update_all(type: nil)
    Event.find_in_batches do |events|
      ActiveRecord::Base.transaction do
        events.each do |event|
          event.distribute_event_type
          event.save!
        end
      end
    end
    event_columns = Event.column_names - ["id", "type"]
    start_id = Event.last.id
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("INSERT INTO events(#{event_columns.join(",")}) SELECT #{event_columns.join(",")} FROM scaling_unity_events")
    end
    Event.where("id > ?", start_id).update_all(type: "UnityEvent")
    drop_table :scaling_unity_events
  end

  def down
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
      t.integer :judge_state, :integer, null: false, default: 0
      t.timestamps
    end
    add_index :scaling_unity_events, %i[event_id type]
    add_index :scaling_unity_events, %i[url]
    add_index :scaling_unity_events, %i[started_at ended_at]
    add_index :scaling_unity_events, :title
  end
end
