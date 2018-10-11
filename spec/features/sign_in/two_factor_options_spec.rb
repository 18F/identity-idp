require 'rails_helper'

describe '2FA options when signing in' do
  context 'when the user only has SMS configured' do
    it 'only displays SMS, Voice and Personal key' do
      user = create(:user, :signed_up, otp_delivery_preference: 'sms')
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has Voice configured' do
    it 'only displays SMS, Voice and Personal key' do
      user = create(:user, :signed_up, otp_delivery_preference: 'voice')
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has SMS configured with a number that we cannot call' do
    it 'only displays SMS and Personal key' do
      user = create(:user, :signed_up,
                    otp_delivery_preference: 'sms', with: { phone: '+12423270143' })
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context "the user's otp_delivery_preference is voice but number is unsupported" do
    it 'only displays SMS and Personal key' do
      user = create(:user, :signed_up,
                    otp_delivery_preference: 'voice', with: { phone: '+12423270143' })
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has TOTP configured' do
    it 'only displays TOTP and Personal key' do
      user = create(:user, :with_authentication_app)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to_not have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user only has PIV/CAC configured' do
    it 'only displays PIV/CAC and Personal key' do
      user = create(:user, :with_piv_or_cac, :with_personal_key)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to_not have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user only has SMS and TOTP configured' do
    it 'only displays SMS, Voice, TOTP and Personal key' do
      user = create(:user, :signed_up, :with_authentication_app)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user only has SMS and PIV/CAC configured' do
    it 'only displays SMS, Voice, PIV/CAC and Personal key' do
      user = create(:user, :signed_up, :with_piv_or_cac)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user only has TOTP and PIV/CAC configured' do
    it 'only displays PIV/CAC, TOTP, and Personal key' do
      user = create(:user, :with_authentication_app, :with_piv_or_cac)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to_not have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user has SMS, TOTP and PIV/CAC configured' do
    it 'only displays SMS, Voice, PIV/CAC, TOTP, and Personal key' do
      user = create(:user, :signed_up, :with_authentication_app, :with_piv_or_cac)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.personal_key')
      expect(page).
        to have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end
end
