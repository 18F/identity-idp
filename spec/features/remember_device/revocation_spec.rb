require 'rails_helper'

feature 'taking an action that revokes remember device' do
  before do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('1000')
  end

  context 'phone' do
    let(:user) { create(:user, :signed_up) }

    it 'revokes remember device when removed' do
      create(:webauthn_configuration, user: user) # The user needs multiple methods to delete phone

      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_link(
        t('forms.buttons.manage'),
        href: manage_phone_url(id: user.phone_configurations.first.id),
      )
      click_on t('forms.phone.buttons.delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'webauthn' do
    let(:user) { create(:user, :signed_up, :with_webauthn) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_on t('account.index.webauthn_delete')
      click_on t('account.index.webauthn_confirm_delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'piv/cac' do
    let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_on t('forms.buttons.disable')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'totp' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_on t('forms.buttons.disable')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'backup codes' do
    let(:user) { create(:user, :signed_up, :with_authentication_app, :with_backup_code) }

    it 'revokes remember device when regenerated' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_on t('forms.backup_code.regenerate')
      click_on t('account.index.backup_code_confirm_regenerate')
      expect(page).to have_content(t('forms.backup_code.subtitle'))
      click_continue
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  def sign_in_with_remember_device_and_sign_out
    sign_in_user(user)
    choose_another_security_option('sms')
    check :remember_device
    fill_in_code_with_last_phone_otp
    click_submit_default
    first(:link, t('links.sign_out')).click
  end

  def expect_mfa_to_be_required_for_user(user)
    sign_in_user(user.reload)

    expected_path = if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
                      login_two_factor_piv_cac_path
                    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
                      login_two_factor_webauthn_path
                    elsif TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
                      login_two_factor_authenticator_path
                    elsif TwoFactorAuthentication::PhonePolicy.new(user).enabled?
                      login_two_factor_path(otp_delivery_preference: :sms, reauthn: false)
                    elsif TwoFactorAuthentication::BackupCodePolicy.new(user).configured?
                      login_two_factor_backup_code_path
                    end

    expect(page).to have_current_path(expected_path)
    visit account_path
    expect(page).to have_current_path(expected_path)
  end
end
