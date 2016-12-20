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

    it_behaves_like 'an otp form'

    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

      render
    end

    it 'has a localized heading' do
      render

      expect(rendered).to have_content @presenter.header
    end

    it 'informs the user that an OTP has been sent to their number' do
      build_stubbed(:user, :signed_up)
      render

      expect(rendered).to include @presenter.help_text
    end

    it 'allows user to resend code' do
      render
      expect(rendered).to have_link(nil, href: @presenter.resend_code_path)
    end

    context 'user signed up' do
      it 'provides an option to use a recovery code' do
        build_stubbed(:user, :signed_up)
        render

        expect(rendered).to have_link(
          t('devise.two_factor_authentication.recovery_code_fallback.link_html'),
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
          t('devise.two_factor_authentication.recovery_code_fallback.link_html'),
          href: login_two_factor_recovery_code_path
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
      it 'has a link to send confirmation with voice' do
        render

        expect(rendered).to have_link(
          t('links.two_factor_authentication.voice_html',
            href: otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' }))
        )
      end
    end

    context 'when choosing to receive OTP via voice' do
      it 'has a link to send confirmation as SMS' do
        controller.request.path_parameters[:delivery_method] = 'voice'
        voice_data = presenter_data.merge(delivery_method: 'voice')
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(voice_data)

        render

        expect(rendered).to have_link(
          t('links.two_factor_authentication.sms_html'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' })
        )
      end
    end
  end
end
