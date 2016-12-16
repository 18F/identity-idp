require 'rails_helper'

describe 'two_factor_authentication/otp_verification/show.html.slim' do
  context 'user has a phone' do
    before do
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:user_session).and_return({})
      allow(view).to receive(:current_user).and_return(User.new)
      controller.request.path_parameters[:delivery_method] = 'sms'
      @delivery_method = 'sms'
    end

    it_behaves_like 'an otp form'

    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

      render
    end

    it 'has a localized heading' do
      render

      expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
    end

    it 'informs the user that an OTP has been sent to their number' do
      user = build_stubbed(:user, :signed_up)
      @phone_number = user.decorate.masked_two_factor_phone_number

      render

      expect(rendered).to have_content t('instructions.2fa.confirm_code', number: '***-***-1212')
    end

    it 'allows user to resend code' do
      render

      expect(rendered).
        to have_link(
          t('links.two_factor_authentication.resend_code'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms',
                                                             resend: true })
        )
    end

    context 'when @code_value is set' do
      it 'pre-populates the form field' do
        @code_value = '12777'

        render

        expect(rendered).to have_xpath("//input[@value='12777']")
      end
    end

    context 'when choosing to receive OTP via SMS' do
      it 'has a link to send confirmation with voice' do
        @delivery_method = 'sms'

        render

        expect(rendered).to have_link(
          t('links.phone_confirmation.fallback_to_voice'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' })
        )
      end
    end

    context 'when choosing to receive OTP via voice' do
      it 'has a link to send confirmation as SMS' do
        controller.request.path_parameters[:delivery_method] = 'voice'
        @delivery_method = 'voice'

        render

        expect(rendered).to have_link(
          t('links.phone_confirmation.fallback_to_sms'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' })
        )
      end
    end
  end
end
