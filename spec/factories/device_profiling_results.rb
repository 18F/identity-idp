FactoryBot.define do
  factory :device_profiling_result do
    association :user
    profiling_type { DeviceProfilingResult::PROFILING_TYPES[:account_creation] }
    review_status { 'pass' }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }

    trait :rejected do
      review_status { 'reject' }
    end

    trait :pending do
      review_status { 'pending' }
    end
  end
end
