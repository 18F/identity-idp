FactoryBot.define do
  factory :throttle do
    throttle_type { :idv_acuant }

    trait :with_throttled do
      attempts { 9999 }
      attempted_at { Time.zone.now }
    end
  end
end
