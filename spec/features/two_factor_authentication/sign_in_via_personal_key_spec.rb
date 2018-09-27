require 'rails_helper'

feature 'Signing in via one-time use personal key' do
  it 'destroys old key, displays new one, and redirects to profile after acknowledging' do
    user = create(:user, :signed_up)
    raw_key = PersonalKeyGenerator.new(user).create
    old_key = user.reload.encrypted_recovery_code_digest

    sign_in_before_2fa(user)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: raw_key)
    click_submit_default
    click_acknowledge_personal_key

    expect(user.reload.encrypted_recovery_code_digest).to_not eq old_key
    expect(current_path).to eq account_path
  end

  context 'user enters incorrect personal key' do
    it 'locks user out when max login attempts has been reached' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
      personal_key = PersonalKeyGenerator.new(user).create
      wrong_personal_key = personal_key.split('-').reverse.join

      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: wrong_personal_key)
      click_submit_default

      expect(page).to have_content(
        t('two_factor_authentication.max_personal_key_login_attempts_reached')
      )
    end
  end
end
