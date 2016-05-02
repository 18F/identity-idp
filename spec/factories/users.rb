FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :user do
    confirmed_at Time.current
    email { Faker::Internet.safe_email }
    password '!1aZ' * 32 # Maximum length password.
    password_confirmation '!1aZ' * 32 # Maximum length password.

    trait :with_mobile do
      second_factor_ids { [SecondFactor.mobile_id] }
      mobile '5005550006'
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
      second_factor_confirmed_at Time.current
    end

    trait :tfa_confirmed do
      second_factor_confirmed_at Time.current
      second_factor_ids { [SecondFactor.find_by_name('Email').id] }
    end

    trait :both_tfa_confirmed do
      second_factor_confirmed_at Time.current
      second_factor_ids do
        [SecondFactor.find_by_name('Email').id,
         SecondFactor.find_by_name('Mobile').id]
      end
    end

    trait :signed_up do
      tfa_confirmed
    end
  end
end
