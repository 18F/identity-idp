FactoryBot.define do
  factory :generic_otp_presenter, class: Hash do
    otp_delivery_preference { 'sms' }
    phone_number { '***-***-1212' }
    code_value { '12777' }
    unconfirmed_user { false }
  end
end
