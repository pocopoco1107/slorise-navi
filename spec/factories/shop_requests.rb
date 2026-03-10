FactoryBot.define do
  factory :shop_request do
    name { "テスト店舗" }
    association :prefecture
    address { "東京都新宿区1-1-1" }
    voter_token { SecureRandom.hex(16) }
    status { :pending }
  end
end
