FactoryBot.define do
  Faker::Config.locale = :en

  factory :email_address do
    confirmed_at { Time.zone.now }
    email { Faker::Internet.safe_email }
    user { association :user }
  end
end
