class AddPworldUrlToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :pworld_url, :string
  end
end
