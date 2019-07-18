FactoryBot.define do
  Faker::Config.locale = :en

  factory :email_address do
    confirmed_at { Time.zone.now }
    confirmation_sent_at { Time.zone.now - 5.minutes }
    email { Faker::Internet.safe_email }
    user { association :user }
  end
end
