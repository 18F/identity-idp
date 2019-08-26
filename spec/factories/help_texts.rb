FactoryBot.define do
  Faker::Config.locale = :en

  factory :help_text do
    sign_in { { "en": Faker::Lorem.sentence } }
    sign_up { { "en": Faker::Lorem.sentence } }
    forgot_password { { "en": Faker::Lorem.sentence } }
  end
end
