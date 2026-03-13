ActiveAdmin.register VoterProfile do
  actions :index, :show

  index do
    id_column
    column :voter_token do |p|
      "ユーザー##{p.voter_token.last(4)}"
    end
    column :total_votes
    column :rank_title
    column :current_streak
    column :max_streak
    column :accuracy_majority
    column :high_setting_rate
    column :last_voted_on
    actions
  end

  filter :rank_title
  filter :total_votes
  filter :current_streak

  show do
    attributes_table do
      row :id
      row :voter_token do |p|
        "ユーザー##{p.voter_token.last(4)}"
      end
      row :total_votes
      row :weekly_votes
      row :monthly_votes
      row :current_streak
      row :max_streak
      row :last_voted_on
      row :rank_title
      row :accuracy_confirmed
      row :accuracy_majority
      row :high_setting_rate
      row :created_at
      row :updated_at
    end
  end
end
