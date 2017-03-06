FactoryGirl.define do
  Faker::Config.locale = 'en-US'

  factory :service_provider do
    cert { 'saml_test_sp' }
    friendly_name 'Test Service Provider'
    issuer { SecureRandom.uuid }
    return_to_sp_url '/'
    agency 'Test Agency'
  end
end
