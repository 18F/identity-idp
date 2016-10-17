FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :user do
    confirmed_at Time.current
    email { Faker::Internet.safe_email }
    password '!1a Z@6s' * 16 # Maximum length password.

    trait :with_phone do
      phone '+1 (202) 555-1212'
      phone_confirmed_at Time.zone.now
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
    end

    trait :signed_up do
      with_phone
      recovery_code '$2a$10$vOkU3l3j0aYgWbXVdwJA5.FICxwydpvPrzBuzjFZUXDnPeXkMHeLe'
    end

    trait :unconfirmed do
      confirmed_at nil
      password nil
    end
  end
end
