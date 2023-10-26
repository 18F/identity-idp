FactoryBot.define do
  Faker::Config.locale = :en

  factory :service_provider do
    certs { ['saml_test_sp'] }
    friendly_name { 'Test Service Provider' }
    issuer { SecureRandom.uuid }
    return_to_sp_url { '/' }
    agency { association :agency }
    launch_date { Date.new(2020, 1, 1) }
    help_text do
      { sign_in: { en: '<strong>custom sign in help text for %{sp_name}</strong>' },
        sign_up: { en: '<strong>custom sign up help text for %{sp_name}</strong>' },
        forgot_password: {
          en: '<strong>custom forgot password help text for %{sp_name}</strong>',
        } }
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

    trait :idv do
      ial { 2 }
    end

    # Can we enable this globally?
    trait :active do
      active { true }
    end

    # Do we need this still?
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
