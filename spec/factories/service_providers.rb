FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :service_provider do
    issuer { SecureRandom.uuid }
    cert { 'saml_test_sp' }
  end
end
