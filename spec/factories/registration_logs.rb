FactoryBot.define do
  factory :registration_log do
    association :user

    registered_at { Time.zone.now }
  end
end