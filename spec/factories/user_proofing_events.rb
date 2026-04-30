FactoryBot.define do
  factory :user_proofing_event do
    service_provider_ids_sent { [] }
    cost { nil }
    salt { nil }
    profile_id { nil }

    trait :existing do
      service_provider_ids_sent { [] }
      cost { '0$0$0$' }
      salt { '73616c74' }
      association :profile
    end
  end
end
