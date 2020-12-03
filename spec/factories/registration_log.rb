FactoryBot.define do
  factory :registration_log do
    user
    submitted_at { Time.zone.now }
  end
end
