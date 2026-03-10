class AddActiveToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :active, :boolean, default: true, null: false
    add_index :machine_models, :active
  end
end
