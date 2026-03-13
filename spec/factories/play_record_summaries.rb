FactoryBot.define do
  factory :play_record_summary do
    scope_type { "shop" }
    sequence(:scope_id) { |n| n }
    period_type { :monthly }
    period_key { Date.current.strftime("%Y-%m") }
    total_records { 0 }
    total_result { 0 }
    avg_result { 0 }
    win_count { 0 }
    lose_count { 0 }
    win_rate { 0.0 }
    weekday_stats { {} }
  end
end
