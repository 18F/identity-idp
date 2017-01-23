require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  let(:presenter) { TwoFactorAuthCode::PhoneDeliveryPresenter.new({}) }

  it 'is a subclass of GenericDeliveryPresenter' do
    expect(TwoFactorAuthCode::PhoneDeliveryPresenter.superclass).to(
      be(TwoFactorAuthCode::GenericDeliveryPresenter)
    )
  end
end
