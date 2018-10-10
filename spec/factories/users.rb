FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    transient do
      with { {} }
    end

    confirmed_at { Time.zone.now }
    email { Faker::Internet.safe_email }
    password { '!1a Z@6s' * 16 } # Maximum length password.

    after(:build) do |user, _evaluator|
      if user.email.present? && user.email_address.nil?
        user.email_address = build(:email_address, email: user.email, user: user)
      end
    end

    after(:stub) do |user, _evaluator|
      if user.email.present? && user.email_address.nil?
        user.email_address = build_stubbed(:email_address, email: user.email, user: user)
      end
    end

    trait :with_webauthn do
      after(:build) do |user, evaluator|
        if user.webauthn_configurations.empty?
          user.save!
          if user.id.present?
            create(:webauthn_configuration,
                   { user: user }.merge(
                     evaluator.with.slice(:name, :credential_id, :credential_public_key)
                   ))
            user.webauthn_configurations.reload
          else
            user.webauthn_configurations << build(
              :webauthn_configuration,
              evaluator.with.slice(:name, :credential_id, :credential_public_key)
            )
          end
        end
      end

      after(:create) do |user, evaluator|
        if user.webauthn_configurations.empty?
          create(:webauthn_configuration,
                 { user: user }.merge(
                   evaluator.with.slice(:name, :credential_id, :credential_public_key)
                 ))
          user.webauthn_configurations.reload
        end
      end

      after(:stub) do |user, evaluator|
        if user.webauthn_configurations.empty?
          user.webauthn_configurations << build(
            :webauthn_configuration,
            evaluator.with.slice(:name, :credential_id, :credential_public_key)
          )
        end
      end
    end

    trait :with_phone do
      after(:build) do |user, evaluator|
        if user.phone_configurations.empty?
          user.save!
          if user.id.present?
            create(:phone_configuration,
                   { user: user, delivery_preference: user.otp_delivery_preference }.merge(
                     evaluator.with.slice(:phone, :confirmed_at, :delivery_preference, :mfa_enabled)
                   ))
            user.phone_configurations.reload
          else
            user.phone_configurations << build(
              :phone_configuration,
              { delivery_preference: user.otp_delivery_preference }.merge(
                evaluator.with.slice(:phone, :confirmed_at, :delivery_preference, :mfa_enabled)
              )
            )
          end
        end
      end

      after(:create) do |user, evaluator|
        if user.phone_configurations.empty?
          create(:phone_configuration,
                 { user: user, delivery_preference: user.otp_delivery_preference }.merge(
                   evaluator.with.slice(:phone, :confirmed_at, :delivery_preference, :mfa_enabled)
                 ))
          user.phone_configurations.reload
        end
      end

      after(:stub) do |user, evaluator|
        if user.phone_configurations.empty?
          user.phone_configurations << build(
            :phone_configuration,
            { delivery_preference: user.otp_delivery_preference }.merge(
              evaluator.with.slice(:phone, :confirmed_at, :delivery_preference, :mfa_enabled)
            )
          )
        end
      end
    end

    trait :with_piv_or_cac do
      x509_dn_uuid { SecureRandom.uuid }
    end

    trait :with_personal_key do
      after :build do |user|
        PersonalKeyGenerator.new(user).create
      end
    end

    trait :with_authentication_app do
      with_personal_key
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
      password { nil }
    end
  end
end
