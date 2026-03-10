class AddIsSmartSlotToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :is_smart_slot, :boolean, default: false, null: false
  end
end
