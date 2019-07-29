FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    password { '!1a Z@6s' * 16 } # Maximum length password.

    transient do
      with { {} }
      email { Faker::Internet.safe_email }
      confirmed_at { Time.zone.now }
    end

    after(:build) do |user, evaluator|
      next unless user.email_addresses.empty?
      user.email_addresses.build(
        email: evaluator.email,
        confirmed_at: evaluator.confirmed_at,
      )
      user.email = evaluator.email
      user.confirmed_at = evaluator.confirmed_at
    end

    after(:stub) do |user, evaluator|
      next unless user.email_addresses.empty?
      user.email_addresses.build(
        email: evaluator.email,
        confirmed_at: evaluator.confirmed_at,
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
      x509_dn_uuid { SecureRandom.uuid }
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
      otp_secret_key { ROTP::Base32.random_base32 }
    end

    trait :admin do
      role { :admin }
    end

    trait :tech_support do
      role { :tech }
    end

    trait :signed_up do
      with_phone
      with_personal_key
    end

    trait :unconfirmed do
      confirmed_at { nil }
      confirmation_sent_at { 5.minutes.ago }
      password { nil }
    end
  end
end
