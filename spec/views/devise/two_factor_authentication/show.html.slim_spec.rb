require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has a phone' do
    let(:user) { build_stubbed(:user, :signed_up) }

    before do
      @phone_number = '***-***-1234'
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:current_user).and_return(user)

      render
    end

    it 'has a localized heading' do
      expect(rendered).to have_content t('headings.choose_otp_delivery')
    end

    it 'allows the user to select OTP delivery method' do
      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.sms')
      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.voice')
    end

    it 'informs the user that an OTP will be sent to their number' do
      content = "We will send it to #{@phone_number}"
      expect(rendered).to have_content(t('headings.choose_otp_delivery'))
      expect(rendered).to have_content content
    end

    it 'provides the user with a link to cancel out of the process' do
      expect(rendered).to have_link(t('links.cancel'), href: destroy_user_session_path)
    end
  end
end
