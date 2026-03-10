class AddDetailFieldsToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :parking_spaces, :integer
    add_column :shops, :phone_number, :string
    add_column :shops, :morning_entry, :string
    add_column :shops, :access_info, :string
    add_column :shops, :features, :string
  end
end
