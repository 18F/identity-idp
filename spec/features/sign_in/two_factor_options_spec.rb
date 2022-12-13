require 'rails_helper'

describe 'when using PIV/CAC to sign in' do
  let(:user) { user_with_piv_cac }

  it 'does not show any MFA options' do
    sign_in_user_with_piv(user)
    expect(page).to_not have_content t('two_factor_authentication.login_options_link_text')
  end
end

describe '2FA options when signing in' do
  context 'when the user only has SMS configured' do
    it 'only displays SMS and Voice' do
      user = create(:user, :signed_up, otp_delivery_preference: 'sms')
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has backup codes configured' do
    it 'only displays backup codes' do
      user = create(:user, :with_backup_code)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to_not have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to have_content t('two_factor_authentication.login_options.backup_code')
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
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has SMS configured with a number that we cannot call' do
    it 'only displays SMS and Personal key' do
      user = create(
        :user,
        :signed_up,
        otp_delivery_preference: 'sms',
        with: { phone: '+12423270143' },
      )
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context "the user's otp_delivery_preference is voice but number is unsupported" do
    it 'only displays SMS and Personal key' do
      user = create(
        :user,
        :signed_up,
        otp_delivery_preference: 'voice',
        with: { phone: '+12423270143' },
      )
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
    end
  end

  context 'when the user only has TOTP configured' do
    it 'only displays TOTP and Personal key' do
      user = create(:user, :with_authentication_app, :with_personal_key)
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
        to_not have_content t('two_factor_authentication.login_options.backup_code')
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
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user only has TOTP and PIV/CAC configured' do
    it 'only displays PIV/CAC, TOTP, and Personal key' do
      user = create(:user, :with_authentication_app, :with_piv_or_cac, :with_personal_key)
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
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to have_content t('two_factor_authentication.login_options.piv_cac')
    end
  end

  context 'when the user has multiple webauthn keys configured' do
    it 'only displays the webauthn option once' do
      user = create(:user, :signed_up)
      create(:webauthn_configuration, user: user)
      create(:webauthn_configuration, user: user)
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).
        to have_content t('two_factor_authentication.login_options.sms')
      expect(page).
        to have_content t('two_factor_authentication.login_options.voice')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.backup_code')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.auth_app')
      expect(page).
        to_not have_content t('two_factor_authentication.login_options.piv_cac')
      expect(page).to have_selector('#two_factor_options_form_selection_webauthn', count: 1)
    end
  end

  context 'when the user has multiple phones configured' do
    it 'displays sms and voice options for each MFA-enabled phone, and only shows last 4 digits' do
      user = create(:user, :signed_up)
      create(:phone_configuration, user: user, phone: '+1 202-555-1213')
      phone_ids = user.reload.phone_configurations.pluck(:id)
      first_id = phone_ids[0]
      second_id = phone_ids[1]
      sign_in_user(user)

      click_link t('two_factor_authentication.login_options_link_text')

      expect(page).to have_selector("#two_factor_options_form_selection_sms_#{first_id}", count: 1)
      expect(page).
        to have_selector("#two_factor_options_form_selection_sms_#{second_id}", count: 1)
      expect(page).to_not have_content('+1 202-555-1212')
      expect(page).to_not have_content('+1 202-555-1213')
      expect(page).to have_content('(***) ***-1212')
      expect(page).to have_content('(***) ***-1213')
      expect(page).
        to have_selector("#two_factor_options_form_selection_voice_#{first_id}", count: 1)
      expect(page).
        to have_selector("#two_factor_options_form_selection_voice_#{second_id}", count: 1)
      expect(page).to have_selector('#two_factor_options_form_selection_personal_key', count: 0)
      expect(page).to have_selector('#two_factor_options_form_selection_backup_code', count: 0)
      expect(page).to have_selector('#two_factor_options_form_selection_auth_app', count: 0)
      expect(page).to have_selector('#two_factor_options_form_selection_piv_cac', count: 0)
      expect(page).to have_selector('#two_factor_options_form_selection_webauthn', count: 0)
    end
  end
end
