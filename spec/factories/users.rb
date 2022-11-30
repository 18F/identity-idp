FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    password { '!1a Z@6s' * 16 } # Maximum length password.

    transient do
      with { {} }
      email { Faker::Internet.safe_email }
      confirmed_at { Time.zone.now }
      confirmation_token { nil }
      confirmation_sent_at { 5.minutes.ago }
    end

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
            email: Faker::Internet.safe_email,
            confirmed_at: user.confirmed_at,
            user_id: -1,
          )
        end
      end
      after(:stub) do |user, _evaluator|
        until user.email_addresses.many?
          user.email_addresses << build(
            :email_address,
            email: Faker::Internet.safe_email,
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
          {
            user_id: -1,
            platform_authenticator: true,
          }.merge(
            evaluator.with.slice(:name, :credential_id, :credential_public_key),
          ),
        )
      end

      after(:stub) do |user, evaluator|
        next unless user.webauthn_configurations.empty?
        user.webauthn_configurations << build(
          :webauthn_configuration,
          { platform_authenticator: true }.
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
        BackupCodeGenerator.new(user).create
      end
    end

    trait :with_authentication_app do
      after :build do |user|
        user.save
        otp_secret_key = ROTP::Base32.random_base32
        user.auth_app_configurations.create(otp_secret_key: otp_secret_key, name: 'My Auth App')
      end
    end

    trait :admin do
      role { :admin }
    end

    trait :tech_support do
      role { :tech }
    end

    trait :signed_up do
      with_phone
    end

    trait :unconfirmed do
      confirmed_at { nil }
      password { nil }
    end

    trait :proofed do
      signed_up

      after :build do |user|
        create(:profile, :active, :verified, :with_pii, user: user)
      end
    end

    trait :with_pending_in_person_enrollment do
      after :build do |user|
        profile = create(:profile, :with_pii, user: user)
        create(:in_person_enrollment, :pending, user: user, profile: profile)
      end
    end

    trait :proofed_with_gpo do
      proofed
      after :build do | user |
        profile = user.active_profile
        gpo_code = create(:gpo_confirmation_code)
        profile.gpo_confirmation_codes << gpo_code
      end
    end

    trait :deactivated_password_reset_profile do
      signed_up

      after :build do |user|
        create(:profile, :password_reset, :with_pii, user: user)
      end
    end
  end
end
