class AddColumnAndChangeMetaEvents < ActiveRecord::Migration[6.1]
  def up
    add_column :events, :og_image_info, :text
    change_column :events, :ended_at, :datetime, null: false
  end

  def down
    remove_column :events, :og_image_info
    change_column :events, :ended_at,:datetime, null: true
  end
end
