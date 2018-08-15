FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    confirmed_at Time.zone.now
    email { Faker::Internet.safe_email }
    password '!1a Z@6s' * 16 # Maximum length password.

    after :build do |user|
      if user.phone
        user.build_phone_configuration(
          phone: user.phone,
          confirmed_at: user.phone_confirmed_at,
          delivery_preference: user.otp_delivery_preference
        )
      end
    end

    after :stub do |user|
      if user.phone
        user.phone_configuration = build_stubbed(:phone_configuration,
                                                 user: user,
                                                 phone: user.phone,
                                                 confirmed_at: user.phone_confirmed_at,
                                                 delivery_preference: user.otp_delivery_preference)
      end
    end

    trait :with_phone do
      phone '+1 202-555-1212'
      phone_confirmed_at Time.zone.now
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
      otp_secret_key 'abc123'
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
    end

    trait :signed_up do
      with_phone
      with_personal_key
    end

    trait :unconfirmed do
      confirmed_at nil
      password nil
    end
  end
end
