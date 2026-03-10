FactoryBot.define do
  factory :feedback do
    name { "MyString" }
    email { "MyString" }
    category { 1 }
    body { "MyText" }
    voter_token { "MyString" }
  end
end
