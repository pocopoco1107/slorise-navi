class AddCeilingAndResetInfoToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :ceiling_info, :jsonb, default: {}
    add_column :machine_models, :reset_info, :jsonb, default: {}
  end
end
