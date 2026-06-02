FactoryBot.define do
  factory :user_proofing_event do
    service_provider_ids_sent { [] }
    profile_id { nil }

    trait :existing do
      service_provider_ids_sent { [] }
      association :profile
    end
  end
end
