require 'rails_helper'

feature 'taking an action that revokes remember device' do
  include NavigationHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  context 'phone' do
    let(:user) { create(:user, :signed_up) }

    it 'revokes remember device when removed' do
      create(:webauthn_configuration, user: user) # The user needs multiple methods to delete phone

      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      click_link(
        t('forms.buttons.manage'),
        href: manage_phone_path(id: user.phone_configurations.first.id),
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
      visit account_two_factor_authentication_path
      click_on t('account.index.webauthn_delete')
      click_on t('account.index.webauthn_confirm_delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'webauthn platform' do
    let(:user) { create(:user, :signed_up, :with_webauthn_platform) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      visit account_two_factor_authentication_path
      click_on t('account.index.webauthn_platform_delete')
      click_on t('account.index.webauthn_platform_confirm_delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'piv/cac' do
    let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      visit account_two_factor_authentication_path
      page.find('.remove-piv').click
      click_on t('account.index.piv_cac_confirm_delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'totp' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    it 'revokes remember device when removed' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      visit account_two_factor_authentication_path
      page.find('.remove-auth-app').click # Delete
      click_on t('account.index.totp_confirm_delete')
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'backup codes' do
    let(:user) { create(:user, :signed_up, :with_authentication_app, :with_backup_code) }

    it 'revokes remember device when regenerated' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      visit account_two_factor_authentication_path
      click_on t('forms.backup_code.regenerate')
      click_on t('account.index.backup_code_confirm_regenerate')
      expect(page).to have_content(t('forms.backup_code.subtitle'))
      click_continue
      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end

    it 'revokes remember device when removed' do
      user.backup_code_configurations.destroy_all
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      visit account_two_factor_authentication_path
      click_on t('forms.backup_code.generate')
      click_continue
      click_continue

      expect(user.reload.backup_code_configurations).to_not be_empty

      click_link(
        t('forms.buttons.delete'),
        href: backup_code_delete_path,
      )
      click_on t('account.index.backup_code_confirm_delete')

      expect(user.reload.backup_code_configurations).to be_empty

      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end
  end

  context 'clicking forget browsers' do
    let(:user) { create(:user, :signed_up) }

    it 'forgets the current browser' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      find_sidenav_forget_browsers_link.click
      click_on(t('forms.buttons.confirm'))

      first(:link, t('links.sign_out')).click

      expect_mfa_to_be_required_for_user(user)
    end

    it 'forgets all browsers' do
      perform_in_browser(:one) do
        sign_in_with_remember_device_and_sign_out
      end

      perform_in_browser(:two) do
        sign_in_with_remember_device_and_sign_out

        sign_in_user(user)
        find_sidenav_forget_browsers_link.click
        click_on(t('forms.buttons.confirm'))

        first(:link, t('links.sign_out')).click

        expect_mfa_to_be_required_for_user(user)
      end

      perform_in_browser(:one) do
        expect_mfa_to_be_required_for_user(user)
      end
    end
  end

  def sign_in_with_remember_device_and_sign_out
    sign_in_user(user)
    choose_another_security_option('sms')
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
    first(:link, t('links.sign_out')).click
  end

  def expect_mfa_to_be_required_for_user(user)
    sign_in_user(user.reload)

    expected_path = if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
                      login_two_factor_piv_cac_path
                    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).platform_enabled?
                      login_two_factor_webauthn_path(platform: true)
                    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
                      login_two_factor_webauthn_path(platform: false)
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
