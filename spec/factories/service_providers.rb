FactoryBot.define do
  Faker::Config.locale = :en

  factory :service_provider do
    certs { ['saml_test_sp'] }
    friendly_name { 'Test SP' }
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
      friendly_name { 'TestSP wo help' }
      help_text do
        { sign_in: {},
          sign_up: {},
          forgot_password: {} }
      end
    end

    trait :with_blank_help_text do
      friendly_name { 'TestSP w blank help' }
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

    trait :external do
      iaa { 'LG1234' }
    end
  end
end
