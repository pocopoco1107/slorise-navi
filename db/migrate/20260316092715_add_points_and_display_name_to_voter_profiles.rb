class AddPointsAndDisplayNameToVoterProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :voter_profiles, :display_name, :string
    add_column :voter_profiles, :points, :integer, default: 0, null: false
  end
end
