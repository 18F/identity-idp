FactoryGirl.define do
  factory :profile do
    association :user, factory: [:user, :signed_up]

    trait :active do
      active true
      activated_at Time.current
    end

    trait :verified do
      verified_at Time.current
    end
  end
end
