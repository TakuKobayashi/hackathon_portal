class ReconstructIndexToEvents < ActiveRecord::Migration[5.2]
  def change
    remove_index :events, %i[event_id type]
    add_index :events, %i[event_id type]
    add_index :events, %i[url]
    remove_index :scaling_unity_events, %i[event_id type]
    add_index :scaling_unity_events, %i[event_id type]
    add_index :scaling_unity_events, %i[url]
  end
end
