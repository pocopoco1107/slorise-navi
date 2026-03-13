FactoryBot.define do
  factory :voter_ranking do
    sequence(:voter_token) { |n| "ranking_token_#{n}" }
    period_type { :weekly }
    period_key { Date.current.strftime("%G-W%V") }
    scope_type { "national" }
    scope_id { nil }
    vote_count { 10 }
    rank_position { 1 }
  end
end
