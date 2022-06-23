FactoryBot.define do
  factory :profile do
    association :user, factory: %i[user signed_up]

    transient do
      pii { false }
    end

    trait :active do
      active { true }
      activated_at { Time.zone.now }
    end

    trait :verified do
      verified_at { Time.zone.now }
    end

    trait :password_reset do
      activated_at { Time.zone.now }
      verified_at { Time.zone.now }
      deactivation_reason { :password_reset }
    end

    trait :verification_cancelled do
      deactivation_reason { :verification_cancelled }
    end

    trait :with_liveness do
      proofing_components { { liveness_check: 'vendor' } }
    end

    trait :with_pii do
      pii { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
    end

    after(:build) do |profile, evaluator|
      if evaluator.pii
        pii_attrs = Pii::Attributes.new_from_hash(evaluator.pii)
        profile.encrypt_pii(pii_attrs, profile.user.password)
      end
    end
  end
end
