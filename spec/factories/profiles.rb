FactoryGirl.define do
  factory :profile do
    association :user, factory: [:user, :signed_up]
    transient do
      pii false
    end

    trait :active do
      active true
      activated_at Time.current
    end

    trait :verified do
      verified_at Time.current
    end

    after(:build) do |profile, evaluator|
      if evaluator.pii
        pii_attrs = Pii::Attributes.new_from_hash(evaluator.pii)
        user_access_key = profile.user.unlock_user_access_key(profile.user.password)
        profile.encrypt_pii(user_access_key, pii_attrs)
      end
    end
  end
end
