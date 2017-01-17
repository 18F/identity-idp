require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  let(:presenter) do
    TwoFactorAuthCode::PhoneDeliveryPresenter.new(
      code_value: '123',
      delivery_method: 'sms',
      phone_number: '123-123-1234'
    )
  end

  it 'is a subclass of GenericDeliveryPresenter' do
    expect(TwoFactorAuthCode::PhoneDeliveryPresenter.superclass).to(
      be(TwoFactorAuthCode::GenericDeliveryPresenter)
    )
  end
end
