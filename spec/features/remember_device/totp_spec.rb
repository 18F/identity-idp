require 'rails_helper'

describe 'Remembering a TOTP device' do
  let(:user) do
    user = build(:user, :signed_up, password: 'super strong password')
    @secret = user.generate_totp_secret
    UpdateUser.new(user: user, attributes: { otp_secret_key: @secret }).call
    user
  end

  it 'does not offer the option to remember device' do
    sign_in_user(user)
    expect(current_path).to eq(login_two_factor_authenticator_path)
    expect(page).to_not have_content(
      t('forms.messages.remember_device'),
    )
  end
end
