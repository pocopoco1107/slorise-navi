class AddSourceToShopEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_events, :source, :string, default: "user", null: false
    change_column_null :shop_events, :voter_token, true
  end
end
