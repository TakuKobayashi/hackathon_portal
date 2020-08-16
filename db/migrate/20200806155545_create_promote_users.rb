class CreatePromoteUsers < ActiveRecord::Migration[6.0]
  def change
    create_table(:promote_users, id: false) do |t|
      t.column :id, 'bigint(20) PRIMARY KEY'
      t.string :user_id, null: false
      t.string :type
      t.string :screen_name, null: false
      t.integer :state, null: false, default: 0
      t.integer :follower_count, null: false, default: 0
      t.integer :follow_count, null: false, default: 0
    end
    add_index :promote_users, %i[user_id type], unique: true
  end
end
