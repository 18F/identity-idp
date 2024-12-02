FactoryBot.define do
  factory :sp_return_log do
    request_id { SecureRandom.uuid }
  end
end
