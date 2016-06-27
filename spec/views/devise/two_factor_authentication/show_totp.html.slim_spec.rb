require 'rails_helper'

describe 'devise/two_factor_authentication/show_totp.html.slim' do
  it 'prompts to enter code from app' do
    user = build_stubbed(:user, :signed_up, otp_secret_key: 123)
    allow(view).to receive(:current_user).and_return(user)

    render

    expect(rendered).to have_content 'Please enter the code from your authenticator app'
    expect(rendered).to have_content "enter the code corresponding to #{user.email}"
  end
end
