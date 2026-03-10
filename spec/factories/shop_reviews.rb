FactoryBot.define do
  factory :shop_review do
    shop
    sequence(:voter_token) { |n| "review_token_#{n}" }
    rating { rand(1..5) }
    body { "テストレビュー本文です。" }
    category { :atmosphere }
    reviewer_name { "テスター" }
  end
end
