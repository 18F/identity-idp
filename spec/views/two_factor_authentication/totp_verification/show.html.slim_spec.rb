require 'rails_helper'

describe 'two_factor_authentication/totp_verification/show.html.slim' do
  let(:user) { build_stubbed(:user, :signed_up, otp_secret_key: 123) }
  let(:presenter_data) do
    attributes_for(:generic_otp_presenter).merge(
      delivery_method: 'authenticator',
      user_email: view.current_user.email
    )
  end

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:reauthn?).and_return(false)

    @presenter = TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(presenter_data)

    render
  end

  it_behaves_like 'an otp form'

  it 'shows the correct header' do
    expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
  end

  it 'shows the correct help text' do
    expect(rendered).to have_content(
      t('instructions.2fa.authenticator.confirm_code_html',
        email: user.email,
        app: APP_NAME)
    )
  end

  it 'allows the user to fallback to SMS and voice' do
    expect(rendered).
      to have_link(t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
                   href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' }))
    expect(rendered).
      to have_link(t('devise.two_factor_authentication.totp_fallback.voice_link_text'),
                   href: otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' }))
  end

  it 'provides an option to use a recovery code' do
    expect(rendered).to have_link(
      t('devise.two_factor_authentication.recovery_code_fallback.link'),
      href: login_two_factor_recovery_code_path
    )
  end
end
