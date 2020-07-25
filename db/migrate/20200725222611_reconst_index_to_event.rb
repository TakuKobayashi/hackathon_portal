class ReconstIndexToEvent < ActiveRecord::Migration[6.0]
  def change
    remove_index :events, :title
    remove_index :events, [:started_at, :ended_at]
    remove_index :events, [:event_id, :type]
    add_index :events, :started_at
    add_index :events, :ended_at
    add_index :events, [:event_id, :informed_from]
  end
end
