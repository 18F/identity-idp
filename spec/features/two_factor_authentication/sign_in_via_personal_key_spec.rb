require 'rails_helper'

RSpec.feature 'Signing in via one-time use personal key' do
  it 'destroys old key, does not offer new one' do
    user = create(
      :user, :fully_registered, :with_phone, :with_personal_key,
      with: { phone: '+1 (202) 345-6789' }
    )
    raw_key = PersonalKeyGenerator.new(user).generate!
    old_key = user.reload.encrypted_recovery_code_digest

    sign_in_before_2fa(user)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: raw_key)
    click_submit_default
    expect(user.reload.encrypted_recovery_code_digest).to_not eq old_key
    expect(page).to have_current_path account_path

    last_message = Telephony::Test::Message.messages.last
    expect(last_message.body).to eq t('telephony.personal_key_sign_in_notice', app_name: APP_NAME)
    expect(last_message.to).to eq user.phone_configurations.take.phone

    expect_delivered_email_count(2)
    expect_delivered_email(
      to: [user.email_addresses.first.email],
      subject: t('user_mailer.personal_key_sign_in.subject'),
    )
    expect_delivered_email(
      to: [user.email_addresses.first.email],
      subject: t('user_mailer.new_device_sign_in_after_2fa.subject', app_name: APP_NAME),
    )
  end

  context 'user enters incorrect personal key' do
    it 'locks user out when max login attempts has been reached' do
      user = create(
        :user,
        :fully_registered,
        second_factor_attempts_count: IdentityConfig.store.login_otp_confirmation_max_attempts - 1,
      )
      sign_in_before_2fa(user)
      personal_key = PersonalKeyGenerator.new(user).generate!
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
