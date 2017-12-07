class CreateAiResourceSummaries < ActiveRecord::Migration[5.1]
  def change
    create_table :ai_resource_summaries do |t|
      t.string :resource_type, null: false
      t.integer :resource_id, null: false
      t.text :body, null: false
      t.integer :order_number, null: false, default: 0
    end

    add_index :ai_resource_summaries, [:resource_type, :resource_id]
  end
end
