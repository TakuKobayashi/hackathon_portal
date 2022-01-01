class SeparateEventTable < ActiveRecord::Migration[6.1]
  def up
    create_table :event_details do |t|
      t.integer :event_id, null: false, limit: 8
      t.text :description
      t.text :og_image_info
    end
    add_index :event_details, :event_id
    move_columns = %i[description og_image_info]
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(
        "INSERT INTO event_details(#{([:event_id] + move_columns).join(',')}) SELECT #{([:id] + move_columns).join(',')} FROM events",
      )
    end
    move_columns.each { |move_column| remove_column :events, move_column }
    remove_column :events, :created_at
    remove_column :events, :updated_at
  end

  def down
    move_columns = %i[description og_image_info]
    add_column :events, :description, :text
    add_column :events, :og_image_info, :text
    add_timestamps(:events, null: false, default: Time.current)
    set_query = move_columns.map { |move_column| "events.#{move_column} = event_details.#{move_column}" }.join(',')
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(
        "UPDATE events,(SELECT * FROM event_details) event_details SET #{set_query} WHERE events.id = event_details.event_id",
      )
    end
    drop_table :event_details
  end
end
