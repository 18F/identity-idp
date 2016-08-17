FactoryGirl.define do
  factory :event do
    user_id 1
    event_type :account_created
    user_agent 'Chrome/120 (MS-DOS)'
    location 'Washington, DC, USA'
  end
end
