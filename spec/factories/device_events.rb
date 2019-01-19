FactoryBot.define do
  factory :device_event do
    device_id { 1 }
    event_type { :account_created }
  end
end
