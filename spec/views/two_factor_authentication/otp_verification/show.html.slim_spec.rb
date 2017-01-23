require 'rails_helper'

describe 'two_factor_authentication/otp_verification/show.html.slim' do
  let(:presenter_data) { attributes_for(:generic_otp_presenter) }

  context 'user has a phone' do
    before do
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:user_session).and_return({})
      allow(view).to receive(:current_user).and_return(User.new)
      controller.request.path_parameters[:delivery_method] = presenter_data[:delivery_method]

      @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(presenter_data)
    end

    context 'common OTP delivery screen behavior' do
      it_behaves_like 'an otp form'

      it 'has a localized title' do
        expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

        render
      end

      it 'has a localized heading' do
        render

        expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
      end
    end

    it 'informs the user that an OTP has been sent to their number via #help_text' do
      build_stubbed(:user, :signed_up)

      code_link = link_to(
        t("links.two_factor_authentication.resend_code.#{@presenter.delivery_method}"),
        @presenter.resend_code_path
      )

      help_text = t("instructions.2fa.#{@presenter.delivery_method}.confirm_code_html",
                    number: @presenter.phone_number_tag,
                    resend_code_link: code_link)

      render

      expect(rendered).to include help_text
    end

    context 'user signed up' do
      it 'provides an option to use a recovery code' do
        build_stubbed(:user, :signed_up)
        render

        expect(rendered).to have_link(
          t('devise.two_factor_authentication.recovery_code_fallback.link'),
          href: login_two_factor_recovery_code_path
        )
      end
    end

    context 'user is unconfirmed' do
      it 'does not provide an option to use a recovery code' do
        unconfirmed_data = presenter_data.merge(unconfirmed_user: true)

        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(unconfirmed_data)
        render

        expect(rendered).not_to have_link(
          t('devise.two_factor_authentication.recovery_code_fallback.link'),
          href: login_two_factor_recovery_code_path
        )
      end
    end

    context 'when totp is not enabled' do
      it 'does not allow user to sign in using an authenticator app' do
        render

        expect(rendered).not_to have_link(
          t('links.two_factor_authentication.app'), href: login_two_factor_authenticator_path
        )
      end
    end

    context 'when totp is enabled' do
      it 'allows user to sign in using an authenticator app' do
        totp_data = presenter_data.merge(totp_enabled: true)
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(totp_data)

        render

        expect(rendered).to have_link(
          t('links.two_factor_authentication.app'), href: login_two_factor_authenticator_path
        )
      end
    end

    context 'when @code_value is set' do
      it 'pre-populates the form field' do
        render

        expect(rendered).to have_xpath("//input[@value='12777']")
      end
    end

    context 'when choosing to receive OTP via SMS' do
      let(:delivery_method) { 'sms' }

      it 'allows user to resend code using the same delivery method' do
        render

        resend_path = otp_send_path(otp_delivery_selection_form: {
                                      otp_method: delivery_method,
                                      resend: true
                                    })

        expect(rendered).to have_link(
          t("links.two_factor_authentication.resend_code.#{delivery_method}"),
          href: resend_path
        )
      end

      it 'has a fallback link to send confirmation with voice' do
        expected_fallback_path = otp_send_path(otp_delivery_selection_form: {
                                                 otp_method: 'voice'
                                               })
        expected_link = link_to(t('links.two_factor_authentication.voice'),
                                expected_fallback_path)

        render

        expect(rendered).to include(
          t("instructions.2fa.#{delivery_method}.fallback_html", link: expected_link)
        )
      end

      it 'does not have a fallback link to send confirmation via SMS' do
        unexpected_fallback_path = otp_send_path(otp_delivery_selection_form: {
                                                   otp_method: delivery_method
                                                 })
        unexpected_link = link_to(
          t("links.two_factor_authentication.#{delivery_method}"),
          unexpected_fallback_path
        )

        render

        expect(rendered).not_to include(
          t('instructions.2fa.voice.fallback_html', link: unexpected_link)
        )
      end
    end

    context 'when choosing to receive OTP via voice' do
      let(:delivery_method) { 'voice' }

      before do
        controller.request.path_parameters[:delivery_method] = delivery_method
        voice_data = presenter_data.merge(delivery_method: delivery_method)
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(voice_data)
      end

      it 'allows user to resend code using the same delivery method' do
        render

        resend_path = otp_send_path(otp_delivery_selection_form: {
                                      otp_method: delivery_method,
                                      resend: true
                                    })

        expect(rendered).to have_link(
          t("links.two_factor_authentication.resend_code.#{delivery_method}"),
          href: resend_path
        )
      end

      it 'has a fallback link to send confirmation as SMS' do
        expected_fallback_path = otp_send_path(otp_delivery_selection_form: {
                                                 otp_method: 'sms'
                                               })
        expected_link = link_to(t('links.two_factor_authentication.sms'),
                                expected_fallback_path)

        render

        expect(rendered).to include(
          t("instructions.2fa.#{delivery_method}.fallback_html", link: expected_link)
        )
      end

      it 'does not have a fallback link to send a confirmation as SMS' do
        unexpected_fallback_path = otp_send_path(otp_delivery_selection_form: {
                                                   otp_method: delivery_method
                                                 })
        unexpected_link = link_to(
          t("links.two_factor_authentication.#{delivery_method}"),
          unexpected_fallback_path
        )

        render

        expect(rendered).not_to include(
          t('instructions.2fa.sms.fallback_html', link: unexpected_link)
        )
      end
    end

    context 'when users phone number is unconfirmed' do
      it 'has a link to choose a new phone number' do
        data = presenter_data.merge(
          unconfirmed_phone: true,
          reenter_phone_number_path: 'some/path'
        )

        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(data)

        render

        expect(rendered).to have_link(
          t('forms.two_factor.try_again'), href: @presenter.reenter_phone_number_path
        )
      end
    end
  end
end
