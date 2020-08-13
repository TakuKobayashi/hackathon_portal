class CreatePromoteFriends < ActiveRecord::Migration[6.0]
  def change
    create_table(:promote_friends, :id => false) do |t|
      t.column :id, 'bigint(20) PRIMARY KEY'
      t.string :type
      t.string :from_user_id, null: false
      t.string :to_user_id, null: false
      t.integer :state, null: false, default: 0
      t.float :score, null: false, default: 0
      t.datetime :followed_at
    end
    add_index :promote_friends, %i[to_user_id from_user_id]
    add_index :promote_friends, :score
    add_index :promote_friends, :followed_at
  end
end
