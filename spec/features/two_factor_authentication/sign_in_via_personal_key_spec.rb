require 'rails_helper'

RSpec.feature 'Signing in via one-time use personal key' do
  it 'destroys old key, does not offer new one' do
    user = create(
      :user, :fully_registered, :with_phone, :with_personal_key,
      with: { phone: '+1 (202) 345-6789' }
    )
    raw_key = PersonalKeyGenerator.new(user).generate!
    old_key = user.reload.encrypted_recovery_code_digest_multi_region

    sign_in_before_2fa(user)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: raw_key)
    click_submit_default

    user.reload
    expect(user.encrypted_recovery_code_digest).to_not be_present
    expect(user.encrypted_recovery_code_digest_multi_region).to_not eq old_key
    expect(page).to have_current_path account_path

    last_message = Telephony::Test::Message.messages.last
    expect(last_message.body).to eq t(
      'telephony.personal_key_sign_in_notice.sms', app_name: APP_NAME
    )
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

  context 'when personal key MFA deprecation phase 1 is enabled' do
    before do
      allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
        .and_return(true)
    end

    it 'warns the user to replace their personal key and does not issue a new one' do
      user = create(
        :user, :fully_registered, :with_phone, :with_personal_key,
        with: { phone: '+1 (202) 345-6789' }
      )
      raw_key = PersonalKeyGenerator.new(user).generate!
      user.reload

      sign_in_before_2fa(user)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: raw_key)
      click_submit_default

      user.reload
      # The personal key MFA user's key is consumed in phase 1: no new key is
      # issued and the existing recovery code is cleared.
      expect(user.has_recovery_code?).to eq(false)
      expect(user.encrypted_recovery_code_digest).to be_blank
      expect(user.encrypted_recovery_code_digest_multi_region).to be_blank

      expect(page).to have_current_path authentication_methods_setup_path
      expect(page).to have_content(t('mfa.personal_key_deprecation_warning'))
    end

    it 'prompts the user for a new MFA method after password then personal key' do
      user = create(
        :user, :fully_registered, :with_phone, :with_personal_key,
        with: { phone: '+1 (202) 345-6789' }
      )
      raw_key = PersonalKeyGenerator.new(user).generate!

      # Step 1: username + password.
      sign_in_before_2fa(user)

      # Step 2: authenticate with the personal key.
      choose_another_security_option('personal_key')
      expect(page).to have_current_path login_two_factor_personal_key_path
      enter_personal_key(personal_key: raw_key)
      click_submit_default

      # Step 3: prompted to select a new MFA method.
      expect(page).to have_current_path authentication_methods_setup_path
      expect(page).to have_content(t('mfa.personal_key_deprecation_warning'))
    end

    # Regression guard for the Phase 1 lockout concern: consuming the personal key
    # must never leave the user without a usable MFA method. Reaching the personal
    # key verification page requires the user to already have another (real) MFA
    # method, because `MfaPolicy#two_factor_enabled?` (and the 2FA options list)
    # ignore the personal key. So after the key is consumed, the user still has
    # that other method and cannot be locked out of their account.
    it 'leaves the user with a usable MFA method after their personal key is consumed' do
      user = create(
        :user, :fully_registered, :with_phone, :with_personal_key,
        with: { phone: '+1 (202) 345-6789' }
      )
      raw_key = PersonalKeyGenerator.new(user).generate!

      sign_in_before_2fa(user)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: raw_key)
      click_submit_default

      user.reload

      # The personal key (recovery code) is gone...
      expect(user.has_recovery_code?).to eq(false)
      expect(TwoFactorAuthentication::PersonalKeyPolicy.new(user).enabled?).to eq(false)

      # ...but the user still has a working, non-personal-key MFA method, so they
      # are not locked out even if they abandon the add-another-method prompt.
      expect(MfaPolicy.new(user).two_factor_enabled?).to eq(true)
      expect(MfaContext.new(user).enabled_mfa_methods_count).to be >= 1
      expect(page).to have_current_path authentication_methods_setup_path
    end

    # Regression for the direct-URL lockout gap: a legacy user whose ONLY
    # credential is a personal key can reach login_two_factor_personal_key via a
    # direct URL (see spec/features/legacy_passwords_spec.rb). Phase 1 must NOT
    # consume their key, since that would leave them with zero credentials.
    it 'does not consume the key of a user whose only credential is a personal key' do
      user = create(:user)
      raw_key = PersonalKeyGenerator.new(user).generate!

      expect(MfaPolicy.new(user).two_factor_enabled?).to eq(false)

      sign_in_before_2fa(user)
      visit login_two_factor_personal_key_path
      enter_personal_key(personal_key: raw_key)
      click_submit_default

      user.reload

      # The personal key is preserved so the user retains a usable credential.
      expect(user.has_recovery_code?).to eq(true)
      expect(TwoFactorAuthentication::PersonalKeyPolicy.new(user).enabled?).to eq(true)
    end
  end

  context 'when both flow feature flags are off (default configuration)' do
    before do
      allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
        .and_return(false)
      allow(IdentityConfig.store).to receive(:enable_add_mfa_redirect_for_personal_key)
        .and_return(false)
    end

    it 'does not prompt the user to add a new MFA method' do
      user = create(
        :user, :fully_registered, :with_phone, :with_personal_key,
        with: { phone: '+1 (202) 345-6789' }
      )
      raw_key = PersonalKeyGenerator.new(user).generate!

      sign_in_before_2fa(user)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: raw_key)
      click_submit_default

      expect(page).to have_current_path account_path
    end
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
