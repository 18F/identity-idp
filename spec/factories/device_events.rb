FactoryBot.define do
  factory :device_event do
    user_id { 1 }
    device_id { 1 }
    event_type { :account_created }
    ip { '127.0.0.1' }
  end
end
