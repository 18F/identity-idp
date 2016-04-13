require "#{Rails.root}/lib/user_updater"

FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :user do
    confirmed_at Time.now
    email { Faker::Internet.safe_email }
    password '!1aZ' * 32  # Maximum length password.
    password_confirmation '!1aZ' * 32  # Maximum length password.

    trait :with_mobile do
      second_factor_ids { [SecondFactor.mobile_id] }
      mobile '5005550006'
    end

    trait :admin do
      role :admin
    end

    trait :tech_support do
      role :tech
      second_factor_confirmed_at Time.now
    end

    trait :tfa_confirmed do
      second_factor_confirmed_at Time.now
      second_factor_ids { [SecondFactor.find_by_name('Email').id] }
    end

    trait :both_tfa_confirmed do
      second_factor_confirmed_at Time.now
      second_factor_ids do
        [SecondFactor.find_by_name('Email').id,
         SecondFactor.find_by_name('Mobile').id]
      end
    end

    trait :security_questions_enabled do
      after(:create) do |user|
        UserUpdater.create_security_answers_for(user)
      end
    end

    trait :with_inactive_security_question do
      after(:create) do |user|
        inactive_question_id = SecurityQuestion.where(active: false).limit(1).pluck(:id).pop

        SecurityQuestion.where(active: true).limit(4).pluck(:id).push(inactive_question_id).each do |id|
          user.security_answers.create!(text: 'My answer', security_question_id: id)
        end
      end
    end

    trait :all_but_account_type do
      account_type nil
      tfa_confirmed
      security_questions_enabled
    end

    trait :signed_up do
      account_type :self
      tfa_confirmed
      security_questions_enabled
    end
  end
end
