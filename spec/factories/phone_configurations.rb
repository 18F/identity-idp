FactoryBot.define do
  Faker::Config.locale = :en

  factory :phone_configuration do
    phone { '+1 202-555-1212' }
    mfa_enabled { true }
    user { association :user }
  end
end
