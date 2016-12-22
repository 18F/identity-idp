require 'rails_helper'

describe 'users/two_factor_authentication/show.html.slim' do
  context 'user has a phone' do
    let(:user) { build_stubbed(:user, :signed_up) }

    before do
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:current_user).and_return(user)
    end

    it_behaves_like 'an otp form'

    it 'has a localized heading' do
      render

      expect(rendered).to have_content t('headings.choose_otp_delivery')
    end

    it 'allows the user to select OTP delivery method' do
      render

      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.sms')
      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.voice')
    end

    it 'informs the user that an OTP will be sent to their number' do
      @phone_number = '***-***-1234'

      render

      expect(rendered).to have_content 'Please select how you would like to ' \
      'receive your one-time passcode for ***-***-1234'
    end
  end
end
