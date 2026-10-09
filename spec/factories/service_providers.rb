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

    trait :active do
      active { true }
    end

    trait :in_person_proofing_enabled do
      in_person_proofing_enabled { true }
      ial { 2 }
      redirect_uris { ['http://localhost:7654/auth/result'] }
    end

    factory :service_provider_without_help_text, traits: [:without_help_text]

    trait :internal do
      iaa { ServiceProvider::IAA_INTERNAL }
    end

    # An agency application registered for delegated access, with the consent-screen content an
    # agency writes about it. Accepts any approved service provider unless
    # allowed_delegation_service_providers is set.
    trait :delegation_application do
      active { true }
      ial { 2 }
      delegation_application { true }
      sequence(:delegation_scope_value) { |n| "application_#{n}" }
      delegation_display_name { { en: 'Housing Assistance Records' } }
      delegation_description do
        { en: 'check where your housing application is in review and whether anything is missing.' }
      end
      delegation_data_provided { { en: ['Case number', 'Current status'] } }
      delegation_access_type { 'read' }
      delegation_learn_more_url { 'https://housing.example.gov/records/about' }
    end

    trait :external do
      iaa { 'LG1234' }
    end
  end
end
