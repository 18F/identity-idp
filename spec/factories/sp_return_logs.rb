FactoryBot.define do
  factory :sp_return_log do
    request_id { SecureRandom.uuid }
    billable { true }
    ial { 1 }
    requested_at { Time.zone.now }
  end
end
