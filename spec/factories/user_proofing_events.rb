FactoryBot.define do
  factory :user_proofing_event do
    encrypted_events{ '6d79206576656e74732061726520656e63727970746564' }
    service_providers_sent { [] }
    cost { '0$0$0$' }
    salt { '73616c74' }
    association :profile
  end
end
