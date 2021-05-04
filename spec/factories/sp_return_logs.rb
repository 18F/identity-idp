FactoryBot.define do
  factory :sp_return_log do
    requested_at { Time.zone.now }
    request_id { SecureRandom.uuid }
  end
end