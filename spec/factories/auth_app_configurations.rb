FactoryBot.define do
  Faker::Config.locale = :en

  factory :auth_app_configuration do
    name do
      Faker::Lorem.unique.words.join(' ')[0, UserSuppliedNameAttributes::MAX_NAME_LENGTH].strip
    end
    otp_secret_key { SecureRandom.hex(16) }
    user
  end
end
