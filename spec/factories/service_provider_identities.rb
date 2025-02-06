FactoryBot.define do
  factory :service_provider_identity do
    acr_values { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }
    uuid { SecureRandom.uuid }
    service_provider { 'https://serviceprovider.com' }
  end

  trait :active do
    last_authenticated_at { Time.zone.now }
  end

  trait :consented do
    last_consented_at { Time.zone.now - 5.minutes }
  end

  trait :soft_deleted_5m_ago do
    deleted_at { Time.zone.now - 5.minutes }
  end

  trait :verified do
    verified_at { Time.zone.now }
  end
end
