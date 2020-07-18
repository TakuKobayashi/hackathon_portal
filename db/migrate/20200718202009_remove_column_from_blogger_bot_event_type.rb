class RemoveColumnFromBloggerBotEventType < ActiveRecord::Migration[6.0]
  def change
    remove_column :blogger_bots, :event_type
  end
end
