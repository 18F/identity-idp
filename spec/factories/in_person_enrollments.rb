FactoryBot.define do
  factory :in_person_enrollment do
    user { association :user, :signed_up }
    profile { association :profile, user: user }
    current_address_matches_id { true }
    selected_location_details { { name: 'BALTIMORE' } }
    unique_id { SecureRandom.hex(9) }

    trait :establishing do
      status { :establishing }
    end

    trait :pending do
      status { :pending }
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status_updated_at { Time.zone.now }
      profile { association :profile, :in_person_pending, user: user }
    end

    trait :passed do
      pending
      status { :passed }
      status_updated_at { Time.zone.now }
      status_check_attempted_at { Time.zone.now }
      profile { association :profile, :in_person_proofed, user: user }
    end

    trait :expired do
      pending
      status { :expired }
      status_updated_at { Time.zone.now }
      status_check_attempted_at { Time.zone.now }
      profile { association :profile, :in_person_pending, user: user }
    end

    trait :failed do
      pending
      status { :failed }
      status_updated_at { Time.zone.now }
      status_check_attempted_at { Time.zone.now }
      profile { association :profile, :in_person_pending, user: user }
    end
  end
end
