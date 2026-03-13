FactoryBot.define do
  factory :play_record do
    shop
    machine_model
    sequence(:voter_token) { |n| "play_token_#{n}" }
    played_on { Date.current }
    result_amount { Faker::Number.between(from: -100_000, to: 100_000) }
    is_public { true }
    memo { "" }
    tags { [] }
  end
end
