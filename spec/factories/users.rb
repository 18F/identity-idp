FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    password { '!1a Z@6s' * 16 } # Maximum length password.

    transient do
      with { {} }
      sequence(:email) { |n| "user#{n}@example.com" }
      confirmed_at { Time.zone.now }
      confirmation_token { nil }
      confirmation_sent_at { 5.minutes.ago }
      registered_at { Time.zone.now }
    end

    created_at { Time.zone.now }
    accepted_terms_at { Time.zone.now if email }

    after(:build) do |user, evaluator|
      next if !evaluator.email.present?
      next unless user.email_addresses.empty?
      user.email_addresses.build(
        email: evaluator.email,
        confirmed_at: evaluator.confirmed_at,
        confirmation_sent_at: evaluator.confirmation_sent_at,
        confirmation_token: evaluator.confirmation_token,
      )
      user.email = evaluator.email
      user.confirmed_at = evaluator.confirmed_at
    end

    after(:stub) do |user, evaluator|
      next if !evaluator.email.present?
      next unless user.email_addresses.empty?
      user.email_addresses.build(
        email: evaluator.email,
        confirmed_at: evaluator.confirmed_at,
        confirmation_sent_at: evaluator.confirmation_sent_at,
        confirmation_token: evaluator.confirmation_token,
      )
      user.email = evaluator.email
      user.confirmed_at = evaluator.confirmed_at
    end

    trait :with_multiple_emails do
      after(:build) do |user, _evaluator|
        until user.email_addresses.many?
          user.email_addresses << build(
            :email_address,
            email: Faker::Internet.email,
            confirmed_at: user.confirmed_at,
            user_id: -1,
          )
        end
      end
      after(:stub) do |user, _evaluator|
        until user.email_addresses.many?
          user.email_addresses << build(
            :email_address,
            email: Faker::Internet.email,
            confirmed_at: user.confirmed_at,
            user_id: -1,
          )
        end
      end
    end

    trait :with_webauthn do
      after(:build) do |user, evaluator|
        next unless user.webauthn_configurations.empty?
        user.webauthn_configurations << build(
          :webauthn_configuration,
          {
            user_id: -1,
          }.merge(
            evaluator.with.slice(:name, :credential_id, :credential_public_key),
          ),
        )
      end

      after(:stub) do |user, evaluator|
        next unless user.webauthn_configurations.empty?
        user.webauthn_configurations << build(
          :webauthn_configuration,
          evaluator.with.slice(:name, :credential_id, :credential_public_key),
        )
      end
    end

    trait :with_webauthn_platform do
      after(:build) do |user, evaluator|
        next unless user.webauthn_configurations.empty?
        user.webauthn_configurations << build(
          :webauthn_configuration,
          :platform_authenticator,
          {
            user_id: -1,
          }.merge(
            evaluator.with.slice(:name, :credential_id, :credential_public_key),
          ),
        )
      end

      after(:stub) do |user, evaluator|
        next unless user.webauthn_configurations.empty?
        user.webauthn_configurations << build(
          :webauthn_configuration,
          :platform_authenticator,
          evaluator.with.slice(:name, :credential_id, :credential_public_key),
        )
      end
    end

    trait :with_phone do
      after(:build) do |user, evaluator|
        next unless user.phone_configurations.empty?
        user.phone_configurations << build(
          :phone_configuration,
          {
            delivery_preference: user.otp_delivery_preference,
            user_id: -1,
          }.merge(
            evaluator.with.slice(
              :phone, :confirmed_at, :delivery_preference, :mfa_enabled
            ),
          ),
        )
      end

      after(:stub) do |user, evaluator|
        next unless user.phone_configurations.empty?
        user.phone_configurations << build(
          :phone_configuration,
          {
            delivery_preference: user.otp_delivery_preference,
          }.merge(
            evaluator.with.slice(
              :phone, :confirmed_at, :delivery_preference, :mfa_enabled
            ),
          ),
        )
      end
    end

    trait :with_piv_or_cac do
      after :build do |user|
        user.save
        user.piv_cac_configurations.create(x509_dn_uuid: 'helloworld', name: 'My PIV Card')
      end
    end

    trait :with_personal_key do
      after :build do |user|
        user.personal_key ||= RandomPhrase.new(num_words: 4).to_s
      end
    end

    trait :with_backup_code do
      after :build do |user|
        user.save
        BackupCodeGenerator.new(user).delete_and_regenerate
      end
    end

    trait :with_authentication_app do
      after :build do |user|
        user.save
        otp_secret_key = ROTP::Base32.random_base32
        user.auth_app_configurations.create(otp_secret_key: otp_secret_key, name: 'My Auth App')
      end
    end

    trait :fully_registered do
      with_phone

      after :create do |user, evaluator|
        user.create_registration_log(registered_at: evaluator.registered_at)
      end
    end

    trait :with_authenticated_device do
      fully_registered
      after(:create) do |user|
        user.devices << create(:device, :authenticated, user:)
      end
    end

    trait :unconfirmed do
      confirmed_at { nil }
      password { nil }
    end

    trait :proofed do
      fully_registered
      confirmed_at { Time.zone.now.round }

      after :build do |user|
        create(
          :profile,
          :active,
          :with_pii,
          user: user,
        )
      end
    end

    trait :proofed_with_selfie do
      fully_registered
      confirmed_at { Time.zone.now.round }

      after :build do |user|
        create(
          :profile,
          :active,
          :verified,
          :with_pii,
          idv_level: :unsupervised_with_selfie,
          user: user,
        )
      end
    end

    trait :with_pending_in_person_enrollment do
      after :build do |user|
        profile = create(:profile, :with_pii, :in_person_verification_pending, user: user)
        create(:in_person_enrollment, :pending, user: user, profile: profile)
      end
    end

    trait :with_establishing_in_person_enrollment do
      after :build do |user|
        create(:in_person_enrollment, :establishing, user: user)
      end
    end

    trait :with_pending_gpo_profile do
      transient do
        code_sent_at { created_at }
      end

      after :create do |user, context|
        profile = create(
          :profile,
          :with_pii,
          gpo_verification_pending_at: context.code_sent_at,
          user: user,
          created_at: context.code_sent_at,
          updated_at: context.code_sent_at,
        )
        create(
          :gpo_confirmation_code,
          profile: profile,
          created_at: context.code_sent_at,
          updated_at: context.code_sent_at,
          code_sent_at: context.code_sent_at,
        )
        create(
          :event,
          user: user,
          device: create(:device, user: user),
          event_type: :gpo_mail_sent,
          created_at: context.code_sent_at,
          updated_at: context.code_sent_at,
        )
      end
    end

    trait :proofed_in_person_enrollment do
      fully_registered
      confirmed_at { Time.zone.now.round }

      after :build do |user|
        profile = create(
          :profile,
          :with_pii,
          :active,
          :verified,
          :in_person_verification_pending,
          user: user,
        )
        create(:in_person_enrollment, :passed, user: user, profile: profile)
      end
    end

    trait :proofed_with_gpo do
      fully_registered
      confirmed_at { Time.zone.now.round }

      after :build do |user|
        profile = create(
          :profile,
          :active,
          :with_pii,
          user: user,
        )
        gpo_code = create(:gpo_confirmation_code)
        profile.gpo_confirmation_codes << gpo_code
        device = create(:device, user: user)
        create(:event, user: user, device: device, event_type: :gpo_mail_sent)
      end
    end

    trait :fraud_review_pending do
      fully_registered

      after :build do |user|
        create(
          :profile,
          :fraud_review_pending,
          :verified,
          :with_pii,
          user: user,
        )
      end
    end

    trait :gpo_pending_with_fraud_rejection do
      with_pending_gpo_profile
      after :create do |user|
        user.pending_profile.fraud_rejection_at = 15.days.ago
        user.pending_profile.fraud_pending_reason = :threatmetrix_reject
      end
    end

    trait :gpo_pending_with_fraud_review do
      with_pending_gpo_profile
      after :create do |user|
        user.pending_profile.fraud_review_pending_at = 15.days.ago
        user.pending_profile.fraud_pending_reason = :threatmetrix_review
      end
    end

    trait :fraud_rejection do
      fully_registered

      after :build do |user|
        create(
          :profile,
          :fraud_rejection,
          :verified,
          :with_pii,
          user: user,
        )
      end
    end

    trait :deactivated_password_reset_profile do
      fully_registered

      after :build do |user|
        create(:profile, :verified, :password_reset, :with_pii, user: user)
      end
    end

    trait :suspended do
      suspended_at { Time.zone.now }
      reinstated_at { nil }
    end

    trait :reinstated do
      suspended_at { Time.zone.now }
      reinstated_at { Time.zone.now + 1.hour }
    end
  end
end
