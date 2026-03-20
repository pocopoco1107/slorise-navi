class RemovePworldColumnsFromShops < ActiveRecord::Migration[8.1]
  def change
    remove_index :shops, :exchange_rate, if_exists: true
    remove_index :shops, :slot_rates, if_exists: true

    remove_column :shops, :pworld_url, :string
    remove_column :shops, :exchange_rate, :integer, default: 0
    remove_column :shops, :slot_rates, :string, default: [], array: true
    remove_column :shops, :former_event_days, :string
    remove_column :shops, :notes, :text
  end
end
