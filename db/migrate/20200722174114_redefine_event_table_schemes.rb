class RedefineEventTableSchemes < ActiveRecord::Migration[6.0]
  def up
    add_column :events, :state, :integer, null: false, default: 0
    change_column_null :events, :address, true
  end

  def down
    remove_column :events, :state
    change_column_null :events, :address, false
  end
end
