class DeleteColumnFromEvents < ActiveRecord::Migration[5.1]
  def up
    remove_column :events, :hash_tag
  end

  def down
    add_column :events, :hash_tag, :string
  end
end
