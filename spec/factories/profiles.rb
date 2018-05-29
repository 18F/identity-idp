FactoryBot.define do
  factory :profile do
    association :user, factory: %i[user signed_up]
    transient do
      pii false
    end

    trait :active do
      active true
      activated_at Time.zone.now
    end

    trait :verified do
      verified_at Time.zone.now
    end

    after(:build) do |profile, evaluator|
      if evaluator.pii
        pii_attrs = Pii::Attributes.new_from_hash(evaluator.pii)
        profile.encrypt_pii(pii_attrs, profile.user.password)
      end
    end
  end
end
