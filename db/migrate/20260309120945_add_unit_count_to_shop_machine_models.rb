class AddUnitCountToShopMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_machine_models, :unit_count, :integer
  end
end
