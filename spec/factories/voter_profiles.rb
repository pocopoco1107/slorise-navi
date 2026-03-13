FactoryBot.define do
  factory :voter_profile do
    sequence(:voter_token) { |n| "profile_token_#{n}" }
    total_votes { 0 }
    weekly_votes { 0 }
    monthly_votes { 0 }
    current_streak { 0 }
    max_streak { 0 }
    rank_title { "見習い" }
  end
end
