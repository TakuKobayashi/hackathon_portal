class RemoveColumnFromQiitaBotEventType < ActiveRecord::Migration[6.0]
  def change
    remove_column :qiita_bots, :event_type
  end
end
