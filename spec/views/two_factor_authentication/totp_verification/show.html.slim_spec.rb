require 'rails_helper'

describe 'two_factor_authentication/totp_verification/show.html.slim' do
  let(:user) { build_stubbed(:user, :signed_up, otp_secret_key: 123) }

  it 'prompts to enter code from app' do
    allow(view).to receive(:current_user).and_return(user)

    render

    expect(rendered).to have_content 'Please enter the code from your authenticator app'
    expect(rendered).to have_content "enter the code corresponding to #{user.email}"
  end

  it 'allows the user to fallback to SMS and voice' do
    allow(view).to receive(:current_user).and_return(user)

    render

    expect(rendered).
      to have_link(t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
                   href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' }))
    expect(rendered).
      to have_link(t('devise.two_factor_authentication.totp_fallback.voice_link_text'),
                   href: otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' }))
  end
end
