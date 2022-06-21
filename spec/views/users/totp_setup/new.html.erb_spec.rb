require 'rails_helper'

describe 'users/totp_setup/new.html.erb' do
  let(:user) { create(:user, :signed_up) }

  context 'user has sufficient factors enabled' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(signing_up: false)
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
      @code = 'D4C2L47CVZ3JJHD7'
      @qrcode = 'qrcode.png'

      @presenter = SetupPresenter.new(
        current_user: user,
        user_fully_authenticated: false,
        user_opted_remember_device_cookie: true,
        remember_device_default: true,
      )
    end

    it 'renders the QR code' do
      render

      expect(rendered).to have_css('#qr-code', text: 'D4C2L47CVZ3JJHD7')
    end

    it 'renders the QR code image with useful alt text' do
      render

      page = Capybara.string(rendered)
      image_tag = page.find_css('img[src^="/images/qrcode.png"]').first
      expect(image_tag).to be
      expect(image_tag['alt']).to eq(I18n.t('image_description.totp_qrcode'))
    end

    it 'renders a link to cancel and go back to the account page' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    it 'has a button to copy the QR code' do
      render

      expect(rendered).to have_button(t('components.clipboard_button.label'), type: 'button')
    end

    it 'has labelled fields' do
      render

      expect(rendered).to have_field(t('forms.totp_setup.totp_step_1'))
      expect(rendered).to have_field(t('forms.totp_setup.totp_step_4'))
    end
  end

  context 'user is setting up 2FA' do
    it 'renders a link to choose a different option' do
      user = create(:user)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(signing_up: true)
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      @code = 'D4C2L47CVZ3JJHD7'
      @qrcode = 'qrcode.png'
      @presenter = TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(
        view: view,
        data: { current_user: user },
        service_provider: nil,
      )

      render

      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: authentication_methods_setup_path,
      )
    end
  end
end
