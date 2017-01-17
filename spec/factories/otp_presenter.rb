FactoryGirl.define do
  factory :generic_otp_presenter, class: Hash do
    delivery_method 'sms'
    phone_number '***-***-1212'
    code_value '12777'
    unconfirmed_user false
  end
end
