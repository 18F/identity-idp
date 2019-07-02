require 'rails_helper'

describe 'users/totp_setup/new.html.slim' do
  let(:user) { create(:user, :signed_up) }

  context 'user has sufficient factors enabled' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(signing_up: false)
      @code = 'D4C2L47CVZ3JJHD7'
      @qrcode = 'qrcode.png'
      @presenter = SetupPresenter.new(user, true)
    end

    it 'renders the QR code' do
      render

      expect(rendered).to have_css('#qr-code', text: 'D4C2L47CVZ3JJHD7')
    end

    it 'renders the QR code image' do
      render

      expect(rendered).to have_css('img[src^="/images/qrcode.png"]')
    end

    it 'renders a link to cancel and go back to the account page' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: account_path)
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
      )

      render

      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: two_factor_options_path,
      )
    end
  end
end
