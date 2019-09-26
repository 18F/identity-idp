FactoryBot.define do
  Faker::Config.locale = :en

  factory :service_provider do
    cert { 'saml_test_sp' }
    friendly_name { 'Test Service Provider' }
    issuer { SecureRandom.uuid }
    return_to_sp_url { '/' }
    agency { 'Test Agency' }
    help_text do
      { 'sign_in': { en: '<b>Some sign-in help text</b>' },
        'sign_up': { en: '<b>Some sign-up help text</b>' },
        'forgot_password': { en: '<b>Some forgot password help text</b>' } }
    end
  end
end
