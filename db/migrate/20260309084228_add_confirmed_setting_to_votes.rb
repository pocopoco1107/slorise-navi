class AddConfirmedSettingToVotes < ActiveRecord::Migration[8.0]
  def change
    # confirmed_setting: array of confirmed setting tags like ["偶数確", "4以上", "6確"]
    add_column :votes, :confirmed_setting, :string, array: true, default: []
    add_index :votes, :confirmed_setting, using: :gin

    # Add confirmed setting distribution to vote_summaries
    add_column :vote_summaries, :confirmed_setting_counts, :jsonb, default: {}
  end
end
