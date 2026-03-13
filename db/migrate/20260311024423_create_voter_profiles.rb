class CreateVoterProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :voter_profiles do |t|
      t.string :voter_token, null: false
      t.integer :total_votes, default: 0, null: false
      t.integer :weekly_votes, default: 0, null: false
      t.integer :monthly_votes, default: 0, null: false
      t.integer :current_streak, default: 0, null: false
      t.integer :max_streak, default: 0, null: false
      t.date :last_voted_on
      t.decimal :accuracy_confirmed, precision: 5, scale: 1
      t.decimal :accuracy_majority, precision: 5, scale: 1
      t.decimal :high_setting_rate, precision: 5, scale: 1
      t.string :rank_title, default: "見習い", null: false

      t.timestamps
    end

    add_index :voter_profiles, :voter_token, unique: true
    add_index :voter_profiles, :rank_title
    add_index :voter_profiles, :total_votes
  end
end
