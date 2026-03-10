FactoryBot.define do
  factory :machine_guide_link do
    association :machine_model
    sequence(:url) { |n| "https://chonborista.com/slot/machine-#{n}/" }
    title { "テスト攻略記事" }
    source { "ちょんぼりすた" }
    link_type { :analysis }
    status { :pending }
  end
end
