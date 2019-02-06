class AddEventTypeToQiitaBots < ActiveRecord::Migration[5.2]
  def change
    add_column :qiita_bots, :event_type, :string
  end
end
