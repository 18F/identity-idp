FactoryGirl.define do
  factory :identity do
    service_provider 'https://serviceprovider.com'

    trait :active do
      last_authenticated_at Time.zone.now
    end

    transient do
      session false
    end

    after(:build) do |identity, evaluator|
      if evaluator.session
        identity.sessions << build(:session, session_id: evaluator.session)
      end
    end
  end
end
