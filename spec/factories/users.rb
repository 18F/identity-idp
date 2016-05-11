FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :user do
    confirmed_at Time.current
    email { Faker::Internet.safe_email }
    password '!1aZ' * 32 # Maximum length password.
    password_confirmation '!1aZ' * 32 # Maximum length password.

    trait :with_mobile do
      mobile '+1 (202) 555-1212'
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
    end

    trait :signed_up do
      with_mobile
    end
  end
end
