class CreatePromoteUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :promote_users do |t|
      t.string :type
      t.string :user_id, null: false
      t.string :screen_name, null: false
      t.integer :state, null: false, default: 0
      t.integer :follower_count, null: false, default: 0
      t.integer :follow_count, null: false, default: 0
    end
    add_index :promote_users, :user_id
  end
end
