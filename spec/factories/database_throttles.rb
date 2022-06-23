FactoryBot.define do
  factory :database_throttle do
    throttle_type { :idv_doc_auth }

    trait :with_throttled do
      attempts { 9999 }
      attempted_at { Time.zone.now }
    end
  end
end
