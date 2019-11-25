require 'rails_helper'

describe AddPhoneForm do
  it_behaves_like 'a phone form'
  it_behaves_like 'an international phone form'
  it_behaves_like 'an otp delivery preference form'

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      phone: '703-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject { described_class.new(user) }
end
