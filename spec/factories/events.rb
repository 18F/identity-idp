FactoryBot.define do
  factory :event do
    event_type { :account_created }
    user

    after(:build) do |event|
      event.device ||= event.user.devices.first || build(:device, user: event.user)
    end
  end
end
