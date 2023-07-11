FactoryBot.define do
  Faker::Config.locale = :en

  factory :webauthn_configuration do
    sequence(:name) { |n| "token #{n}" }
    sequence(:credential_id) { |n| "credential #{n}" }
    sequence(:credential_public_key) { |n| "key #{n}" }
    transports { ['usb'] }
    user { association :user }

    trait :platform_authenticator do
      platform_authenticator { true }
      transports { ['internal', 'hybrid'] }
    end
  end
end
