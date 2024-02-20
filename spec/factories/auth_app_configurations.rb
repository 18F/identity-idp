FactoryBot.define do
  Faker::Config.locale = :en

  factory :auth_app_configuration do
    name { Faker::Lorem.unique.words.join(' ') }
    otp_secret_key { SecureRandom.hex(16) }
    user
  end
end
