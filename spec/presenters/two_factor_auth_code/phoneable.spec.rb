require 'rails_helper'

describe TwoFactorAuthCode::Phoneable do
  let(:presenter) do
    TwoFactorAuthCode::PhoneDeliveryPresenter.new(attributes_for(:generic_otp_presenter))
  end

  it 'provides public methods' do
    %w(phone_fallback_link resend_code_path phone_number_tag update_phone_link).each do |m|
      expect(presenter).to respond_to(m.to_sym)
    end
  end
end
