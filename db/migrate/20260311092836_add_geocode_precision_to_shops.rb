class AddGeocodePrecisionToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :geocode_precision, :integer, default: 0, null: false
  end
end
