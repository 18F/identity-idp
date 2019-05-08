require 'rails_helper'

describe 'Set default 2FA phone number' do
  context 'when the user has not set a default phone number' do
    it 'uses the first phone created as the default' do
      user = create(:user, :with_phone)
      create(:phone_configuration, user: user,
                                   phone: '+1 202-555-2323',
                                   created_at: Time.zone.now + 1.hour)

      sign_in_before_2fa(user)
      t('instructions.mfa.sms.number_message',
        number: '***-***-1212',
        expiration: Figaro.env.otp_valid_for)
    end
  end

  context 'when the user sets a default phone number with sms delivery' do
    it 'displays the new default number for 2FA with sms message' do
      user = create(:user, :with_phone)
      phone_config2 = create(:phone_configuration, user: user,
                                                   phone: '+1 202-555-2323',
                                                   created_at: Time.zone.now + 1.hour)

      sign_in_and_2fa_user(user)
      visit manage_phone_path(id: phone_config2.id)
      expect(page).to have_content t('two_factor_authentication.otp_make_default_number.label')

      check 'user_phone_form_otp_make_default_number'
      click_button t('forms.buttons.submit.confirm_change')
      expect(page).to have_content t('account.index.default')

      first(:link, t('links.sign_out')).click
      sign_in_before_2fa(user)
      t('instructions.mfa.sms.number_message',
        number: '***-***-2323',
        expiration: Figaro.env.otp_valid_for)
    end
  end

  context 'when the user sets a default phone number with voice delivery' do
    it 'displays the new default number for 2FA with voice message' do
      user = create(:user, :with_phone)
      phone_config2 = create(:phone_configuration, user: user,
                                                   phone: '+1 202-555-2323',
                                                   created_at: Time.zone.now + 1.hour,
                                                   delivery_preference: 1)

      sign_in_and_2fa_user(user)
      visit manage_phone_path(id: phone_config2.id)
      expect(page).to have_content t('two_factor_authentication.otp_make_default_number.label')

      check 'user_phone_form_otp_make_default_number'
      click_button t('forms.buttons.submit.confirm_change')
      expect(page).to have_content t('account.index.default')

      first(:link, t('links.sign_out')).click
      sign_in_before_2fa(user)
      t('instructions.mfa.voice.number_message',
        number: '***-***-2323',
        expiration: Figaro.env.otp_valid_for)
    end
  end
end
