FactoryBot.define do
  Faker::Config.locale = :en

  factory :user do
    confirmed_at Time.zone.now
    email { Faker::Internet.safe_email }
    password '!1a Z@6s' * 16 # Maximum length password.

    trait :with_phone do
      phone '+1 (202) 555-1212'
      phone_confirmed_at Time.zone.now
    end

    trait :with_piv_or_cac do
      x509_dn_uuid { SecureRandom.uuid }
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
    end

    trait :signed_up do
      with_phone
      after :build do |user|
        user.personal_key = PersonalKeyGenerator.new(user).create
      end
    end

    trait :unconfirmed do
      confirmed_at nil
      password nil
    end
  end
end
