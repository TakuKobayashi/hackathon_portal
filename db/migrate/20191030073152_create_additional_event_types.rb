class CreateAdditionalEventTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :additional_event_types do |t|
      t.integer :event_id, null: false
      t.string :event_type, null: false
    end
    add_index :additional_event_types, %i[event_id]
  end
end
