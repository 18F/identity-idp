FactoryGirl.define do
  factory :identity do
    uuid { SecureRandom.uuid }
    service_provider 'https://serviceprovider.com'
  end

  trait :active do
    last_authenticated_at Time.zone.now
  end
end
