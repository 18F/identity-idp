FactoryBot.define do
  factory :account_recovery_request do
    user
    state { AccountRecoveryRequest::REQUESTED }
    requested_at { Time.zone.now }

    trait :waiting do
      state { AccountRecoveryRequest::WAITING }
    end

    trait :granted do
      state { AccountRecoveryRequest::GRANTED }
      granted_at { Time.zone.now }
      token_fingerprint { Pii::Fingerprinter.fingerprint(SecureRandom.urlsafe_base64(32)) }
      token_expires_at { Time.zone.now + 24.hours }
    end

    trait :link_verified do
      granted
      state { AccountRecoveryRequest::LINK_VERIFIED }
      link_verified_at { Time.zone.now }
    end

    trait :password_verified do
      link_verified
      state { AccountRecoveryRequest::PASSWORD_VERIFIED }
      password_verified_at { Time.zone.now }
    end

    trait :replacement_mfa_pending do
      password_verified
      state { AccountRecoveryRequest::REPLACEMENT_MFA_PENDING }
    end

    trait :completed do
      state { AccountRecoveryRequest::COMPLETED }
      completed_at { Time.zone.now }
    end

    trait :cancelled do
      state { AccountRecoveryRequest::CANCELLED }
      cancelled_at { Time.zone.now }
    end

    trait :expired do
      state { AccountRecoveryRequest::EXPIRED }
      expired_at { Time.zone.now }
    end

    trait :superseded do
      state { AccountRecoveryRequest::SUPERSEDED }
      superseded_at { Time.zone.now }
    end
  end
end
