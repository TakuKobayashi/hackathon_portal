class CustomizeColumnEventAndUnityEvent < ActiveRecord::Migration[5.2]
  def change
    remove_column :events, :location_image_binary
    remove_column :scaling_unity_events, :location_image_binary
    add_column :events, :judge_state, :integer, null: false, default: 0
    add_column :scaling_unity_events, :judge_state, :integer, null: false, default: 0
  end
end
