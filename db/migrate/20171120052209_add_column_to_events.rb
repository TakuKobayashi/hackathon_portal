class AddColumnToEvents < ActiveRecord::Migration[5.1]
  def change
    add_column :events, :hash_tag, :string
  end
end
