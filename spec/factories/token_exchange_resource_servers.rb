FactoryBot.define do
  factory :token_exchange_resource_server do
    sequence(:identifier) { |n| "https://records-api-#{n}.housing.example.gov" }
    service_provider { association :service_provider, :delegation_application }
    certs { ['saml_test_sp'] }
    token_format { 'oauth' }
    active { true }

    trait :saml do
      token_format { 'saml2' }
    end
  end
end
