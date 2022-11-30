FactoryBot.define do
  factory :service_provider_identity do
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
end
