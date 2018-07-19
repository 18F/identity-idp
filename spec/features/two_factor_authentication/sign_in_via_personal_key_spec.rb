require 'rails_helper'

feature 'Signing in via one-time use personal key' do
  it 'destroys old key, displays new one, and redirects to profile after acknowledging' do
    user = create(:user, :signed_up)
    sign_in_before_2fa(user)

    personal_key = PersonalKeyGenerator.new(user).create

    click_link t('devise.two_factor_authentication.personal_key_fallback.link')

    enter_personal_key(personal_key: personal_key)

    click_submit_default
    click_acknowledge_personal_key

    expect(user.reload.personal_key).to_not eq personal_key
    expect(current_path).to eq account_path
  end

  context 'user enters incorrect personal key' do
    it 'locks user out when max login attempts has been reached' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
      personal_key = PersonalKeyGenerator.new(user).create
      wrong_personal_key = personal_key.split('-').reverse.join

      click_link t('devise.two_factor_authentication.personal_key_fallback.link')
      enter_personal_key(personal_key: wrong_personal_key)
      click_submit_default

      expect(page).to have_content(
        t('devise.two_factor_authentication.max_personal_key_login_attempts_reached')
      )
    end
  end
end
