FactoryBot.define do
  factory :in_person_enrollment do
    current_address_matches_id { true }
    profile { association :profile, user: user }
    selected_location_details { { name: 'BALTIMORE' } }
    unique_id { InPersonEnrollment.generate_unique_id }
    user { association :user, :fully_registered }
    sponsor_id { IdentityConfig.store.usps_ipp_sponsor_id }

    trait :establishing do
      profile { nil }
      status { :establishing }
    end

    trait :pending do
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status { :pending }
      status_updated_at { Time.zone.now }
      profile do
        association(
          :profile,
          :in_person_verification_pending,
          user: user,
          in_person_enrollment: instance,
          in_person_verification_pending_at: Time.zone.now,
        )
      end
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
      proofed_at { Time.zone.now }
      status { :failed }
      status_check_attempted_at { Time.zone.now }
      status_updated_at { Time.zone.now }
    end

    trait :in_fraud_review do
      enrollment_code { Faker::Number.number(digits: 16) }
      enrollment_established_at { Time.zone.now }
      status { :in_fraud_review }
      status_updated_at { Time.zone.now }
      profile do
        association(
          :profile,
          :fraud_review_pending,
          user: user,
          in_person_enrollment: instance,
        )
      end
    end

    trait :with_service_provider do
      service_provider { association :service_provider }
    end

    trait :with_notification_phone_configuration do
      association :notification_phone_configuration
    end

    trait :enhanced_ipp do
      sponsor_id { IdentityConfig.store.usps_eipp_sponsor_id }
    end
  end
end
