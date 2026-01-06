FactoryBot.define do
  Faker::Config.locale = :en

  factory :auth_app_configuration do
    name { Faker::Lorem.unique.words.join(' ')[0, 19] }
    otp_secret_key { SecureRandom.hex(16) }
    user
  end
end
