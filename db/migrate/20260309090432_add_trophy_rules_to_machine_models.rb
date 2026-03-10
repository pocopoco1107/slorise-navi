class AddTrophyRulesToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :trophy_rules, :jsonb, default: {}
  end
end
