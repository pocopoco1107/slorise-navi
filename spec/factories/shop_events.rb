FactoryBot.define do
  factory :shop_event do
    shop
    event_date { Date.current + 3.days }
    event_type { :filming }
    title { "スロパチステーション取材" }
    voter_token { SecureRandom.hex(16) }
    source { "user" }
    status { :pending }

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :auto_collected do
      voter_token { nil }
      source { "ptown" }
      status { :approved }
    end

    trait :past do
      event_date { Date.current - 3.days }
    end

    trait :upcoming do
      event_date { Date.current + 3.days }
    end
  end
end
