require 'rails_helper'

describe 'devise/two_factor_authentication/confirm_totp.html.slim' do
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

    expect(rendered).to have_link('receive a code via SMS',
                                  href: otp_send_path(delivery_method: :sms))
    expect(rendered).to have_link('with a phone call',
                                  href: otp_send_path(delivery_method: :voice))
  end
end
