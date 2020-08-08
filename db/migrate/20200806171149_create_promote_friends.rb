class CreatePromoteFriends < ActiveRecord::Migration[6.0]
  def change
    create_table :promote_friends do |t|
      t.string :type
      t.string :from_user_id, null: false
      t.string :to_user_id, null: false
      t.integer :state, null: false, default: 0
      t.timestamps
    end
    add_index :promote_friends, %i[to_user_id from_user_id]
    add_index :promote_friends, :created_at
  end
end
