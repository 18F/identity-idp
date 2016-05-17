FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  sequence :mobile do |n|
    (9_990_000_000 + n).to_s
  end

  factory :user do
    confirmed_at Time.current
    email { Faker::Internet.safe_email }
    password '!1aZ' * 32 # Maximum length password.
    password_confirmation '!1aZ' * 32 # Maximum length password.

    trait :with_mobile do
      mobile
      mobile_confirmed_at Time.new
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
