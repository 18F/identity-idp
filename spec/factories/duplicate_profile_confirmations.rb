FactoryBot.define do
  factory :duplicate_profile_confirmation do
    association :profile
    confirmed_at { Time.zone.now }
    duplicate_profile_ids { [] }
  end
end
