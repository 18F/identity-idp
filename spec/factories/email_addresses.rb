FactoryBot.define do
  Faker::Config.locale = :en

  factory :email_address do
    confirmed_at { Time.zone.now }
    confirmation_sent_at { Time.zone.now - 5.minutes }
    email { Faker::Internet.email }
    user { association :user }

    trait :unconfirmed do
      confirmed_at { nil }
      confirmation_sent_at { 5.minutes.ago }
    end
  end
end
