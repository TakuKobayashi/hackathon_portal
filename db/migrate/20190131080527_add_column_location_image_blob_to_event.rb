class AddColumnLocationImageBlobToEvent < ActiveRecord::Migration[5.2]
  def change
    add_column :events, :location_image_binary, :binary, :limit => 1600.kilobyte
  end
end
