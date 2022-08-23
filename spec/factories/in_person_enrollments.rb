FactoryBot.define do
  factory :in_person_enrollment do
    user { association :user, :signed_up }
    profile { association :profile, user: user }
    unique_id { Faker::Number.hexadecimal(digits: 18) }
    current_address_matches_id { true }
    selected_location_details do { name: 'BALTIMORE' } end

    trait :establishing do
      after :build do |enrollment|
        enrollment.status = :establishing
      end
    end

    trait :pending do
      after :build do |enrollment|
        enrollment.status = :pending
        enrollment.enrollment_code = Faker::Number.number(digits: 16)
        enrollment.enrollment_established_at = Time.zone.now
        enrollment.status_updated_at = Time.zone.now
      end
    end

    trait :expired do
      after :build do |enrollment|
        enrollment.status = :expired
        enrollment.enrollment_code = Faker::Number.number(digits: 16)
        enrollment.enrollment_established_at = Time.zone.now
        enrollment.status_check_attempted_at = Time.zone.now
        enrollment.status_updated_at = Time.zone.now
      end
    end

    trait :failed do
      after :build do |enrollment|
        enrollment.status = :failed
        enrollment.enrollment_code = Faker::Number.number(digits: 16)
        enrollment.enrollment_established_at = Time.zone.now
        enrollment.status_check_attempted_at = Time.zone.now
        enrollment.status_updated_at = Time.zone.now
      end
    end
  end
end
