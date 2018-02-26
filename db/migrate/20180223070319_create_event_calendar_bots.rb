class CreateEventCalendarBots < ActiveRecord::Migration[5.1]
  def change
    create_table :event_calendar_bots do |t|
      t.string :from_type, null: false
      t.integer :from_id, null: false
      t.string :calender_event_id, null: false
      t.timestamps
    end
    add_index :event_calendar_bots, [:from_type, :from_id]
    add_index :event_calendar_bots, :calender_event_id
  end
end
