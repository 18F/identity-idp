FactoryBot.define do
  Faker::Config.locale = :en

  factory :service_provider do
    certs { ['saml_test_sp'] }
    friendly_name { 'Test Service Provider' }
    issuer { SecureRandom.uuid }
    return_to_sp_url { '/' }
    agency { association :agency }
    help_text do
      { sign_in: { en: '<b>custom sign in help text for %{sp_name}</b>' },
        sign_up: { en: '<b>custom sign up help text for %{sp_name}</b>' },
        forgot_password: { en: '<b>custom forgot password help text for %{sp_name}</b>' } }
    end

    trait :without_help_text do
      friendly_name { 'Test Service Provider without help text' }
      help_text do
        { sign_in: {},
          sign_up: {},
          forgot_password: {} }
      end
    end

    trait :with_blank_help_text do
      friendly_name { 'Test Service Provider with blank help text' }
      help_text do
        { sign_in: { en: '' },
          sign_up: { en: '' },
          forgot_password: { en: '' } }
      end
    end

    trait :irs do
      friendly_name { 'An IRS Service Provider' }
      ial { 2 }
      active { true }
      irs_attempts_api_enabled { true }
      redirect_uris { ['http://localhost:7654/auth/result'] }
    end

    factory :service_provider_without_help_text, traits: [:without_help_text]
  end
end
