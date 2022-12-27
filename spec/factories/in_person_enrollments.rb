FactoryBot.define do
  factory :in_person_enrollment do
    current_address_matches_id { true }
    profile { association :profile, user: user }
    selected_location_details { { name: 'BALTIMORE' } }
    unique_id { InPersonEnrollment.generate_unique_id }
    user { association :user, :signed_up }

    trait :establishing do
      status { :establishing }
    end

    trait :pending do
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status { :pending }
      status_updated_at { Time.zone.now }
    end

    trait :expired do
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status { :expired }
      status_check_attempted_at { Time.zone.now }
      status_updated_at { Time.zone.now }
    end

    trait :failed do
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status { :failed }
      status_check_attempted_at { Time.zone.now }
      status_updated_at { Time.zone.now }
    end

    trait :with_service_provider do
      service_provider { association :service_provider }
    end
  end
end
