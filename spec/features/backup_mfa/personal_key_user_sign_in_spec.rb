require 'rails_helper'

describe 'personal key enabled user sign in' do
  it 'does not prompt the user to setup backup mfa on sign in' do
    user = create(:user, :with_phone, :with_personal_key)

    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(account_path)
  end
end
