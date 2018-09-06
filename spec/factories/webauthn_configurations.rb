FactoryBot.define do
  Faker::Config.locale = :en

  factory :webauthn_configuration do
    sequence(:name) { |n| "token #{n}" }
    sequence(:credential_id) { |n| "credential #{n}" }
    sequence(:credential_public_key) { |n| "key #{n}" }
    user { association :user }
  end
end
