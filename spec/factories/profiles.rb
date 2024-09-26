FactoryBot.define do
  factory :profile do
    association :user, factory: %i[user fully_registered]

    transient do
      pii { false }
    end

    idv_level { :legacy_unsupervised }

    trait :active do
      active { true }
      activated_at { Time.zone.now }
      verified_at { Time.zone.now }
    end

    trait :deactivated do
      active { false }
      activated_at { Time.zone.now }
    end

    # TODO: just use active
    trait :verified do
      verified_at { Time.zone.now }
      activated_at { Time.zone.now }
    end

    trait :password_reset do
      active { false }
      deactivation_reason { :password_reset }
    end

    trait :encryption_error do
      active { false }
      deactivation_reason { :encryption_error }
    end

    trait :in_person_verification_pending do
      in_person_verification_pending_at { 15.days.ago }
      idv_level { :legacy_in_person }
    end

    trait :fraud_pending_reason do
      fraud_pending_reason { 'threatmetrix_review' }
      proofing_components { { threatmetrix_review_status: 'review' } }
    end

    trait :fraud_review_pending do
      fraud_pending_reason { 'threatmetrix_review' }
      fraud_review_pending_at { 15.days.ago }
      proofing_components { { threatmetrix_review_status: 'review' } }
    end

    trait :verify_by_mail_pending do
      gpo_verification_pending_at { 1.day.ago }
    end

    # flagged by TM for review, eventually rejected by us
    trait :fraud_rejection do
      fraud_pending_reason { 'threatmetrix_review' }
      fraud_rejection_at { 15.days.ago }
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

    trait :letter_sends_rate_limited do
      gpo_confirmation_codes do
        build_list(:gpo_confirmation_code, IdentityConfig.store.max_mail_events)
      end
    end

    trait :biometric_proof do
      idv_level { :in_person }
      initiating_service_provider_issuer { 'urn:gov:gsa:openidconnect:inactive:sp:test' }
    end

    after(:build) do |profile, evaluator|
      if evaluator.pii
        pii_attrs = Pii::Attributes.new_from_hash(evaluator.pii)
        profile.encrypt_pii(pii_attrs, profile.user.password)
      end
    end
  end
end
