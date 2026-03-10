class AddMachineDetailFieldsToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :generation, :string
    add_column :machine_models, :payout_rate_min, :decimal, precision: 4, scale: 1
    add_column :machine_models, :payout_rate_max, :decimal, precision: 4, scale: 1
    add_column :machine_models, :introduced_on, :date
    add_column :machine_models, :image_url, :string
    add_column :machine_models, :type_detail, :string
    add_column :machine_models, :pworld_machine_id, :integer
    add_column :machine_models, :certification_number, :string

    add_index :machine_models, :pworld_machine_id, unique: true, where: "pworld_machine_id IS NOT NULL"
  end
end
