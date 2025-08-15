FactoryBot.define do
  factory :duplicate_profile do
    profile_ids { [] }
    service_provider { nil }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
