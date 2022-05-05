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
      deactivation_reason { :password_reset }
    end

    trait :with_liveness do
      proofing_components { { liveness_check: 'vendor' } }
    end

    trait :with_pii do
      pii do
        DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC.merge(
          ssn: DocAuthHelper::GOOD_SSN,
          phone: '+1 (555) 555-1234',
        )
      end
    end

    after(:build) do |profile, evaluator|
      if evaluator.pii
        pii_attrs = Pii::Attributes.new_from_hash(evaluator.pii)
        profile.encrypt_pii(pii_attrs, profile.user.password)
      end
    end
  end
end
