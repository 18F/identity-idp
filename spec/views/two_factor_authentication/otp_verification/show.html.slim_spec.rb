require 'rails_helper'

describe 'two_factor_authentication/otp_verification/show.html.slim' do
  context 'user has a phone' do
    before do
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:user_session).and_return({})
      allow(view).to receive(:current_user).and_return(User.new)
      controller.request.path_parameters[:delivery_method] = 'sms'
      @delivery_method = 'sms'
      @resend_otp_code_path = otp_send_path(otp_delivery_selection_form: {
                                              otp_method: 'sms',
                                              resend: true
                                            })
    end

    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

      render
    end

    it 'has a localized heading' do
      render

      expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
    end

    context 'user chooses either sms or voice delivery' do
      it 'informs the user that an OTP has been sent to their number via sms' do
        user = build_stubbed(:user, :signed_up)
        @phone_number = user.decorate.masked_two_factor_phone_number

        render

        expect(rendered).to have_content t('instructions.2fa.confirm_code_sms',
                                           number: '***-***-1212')
      end

      it 'informs the user that an OTP has been sent to their number via voice' do
        user = build_stubbed(:user, :signed_up)
        @delivery_method = 'voice'
        @phone_number = user.decorate.masked_two_factor_phone_number

        render

        expect(rendered).to have_content t('instructions.2fa.confirm_code_voice',
                                           number: '***-***-1212')
      end
    end

    it 'allows user to resend code' do
      render

      expect(rendered).
        to have_link(
          t('links.phone_confirmation.resend_code'), href: @resend_otp_code_path
        )
    end

    it 'allows the user to use an authenticator app if enabled' do
      allow(view.current_user).to receive(:totp_enabled?).and_return(true)
      render

      expect(rendered).to have_link(t('devise.two_factor_authentication.totp_name'),
                                    href: login_two_factor_authenticator_path)
    end

    it 'does not show the authenticator link if not enabled' do
      render
      expect(rendered).not_to have_link(t('devise.two_factor_authentication.totp_name'),
                                        href: login_two_factor_authenticator_path)
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
