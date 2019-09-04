require 'rails_helper'

feature 'Signing in via one-time use personal key' do
  it 'destroys old key, displays new one, notifies, and redirects to profile after acknowledging' do
    user = create(:user, :signed_up, :with_phone, with: { phone: '+1 (202) 345-6789' })
    raw_key = PersonalKeyGenerator.new(user).create
    old_key = user.reload.encrypted_recovery_code_digest

    personal_key_sign_in_mail = double
    expect(personal_key_sign_in_mail).to receive(:deliver_now)
    expect(UserMailer).to receive(:personal_key_sign_in).and_return(personal_key_sign_in_mail)
    expect(Telephony).to receive(:send_personal_key_sign_in_notice).
      with(to: '+1 (202) 345-6789')

    sign_in_before_2fa(user)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: raw_key)
    click_submit_default
    expect(user.reload.encrypted_recovery_code_digest).to_not eq old_key
    expect(current_path).to eq two_factor_options_path
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
        t('two_factor_authentication.max_personal_key_login_attempts_reached'),
      )
    end
  end
end
