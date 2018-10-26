FactoryBot.define do
  Faker::Config.locale = :en

  factory :email_address do
    confirmed_at { Time.zone.now }
    email { 'jd@example.com' }
    user { association :user }
  end
end
