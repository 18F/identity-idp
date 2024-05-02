require 'rails_helper'

RSpec.feature 'taking an action that revokes remember device' do
  include NavigationHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  context 'clicking forget browsers' do
    let(:user) { create(:user, :fully_registered) }

    it 'forgets the current browser' do
      sign_in_with_remember_device_and_sign_out

      sign_in_user(user)
      find_sidenav_forget_browsers_link.click
      click_on(t('forms.buttons.confirm'))

      first(:button, t('links.sign_out')).click

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

        first(:button, t('links.sign_out')).click

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
    first(:button, t('links.sign_out')).click
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
                      login_two_factor_path(otp_delivery_preference: :sms)
                    elsif TwoFactorAuthentication::BackupCodePolicy.new(user).configured?
                      login_two_factor_backup_code_path
                    end

    expect(page).to have_current_path(expected_path)
    visit account_path
    expect(page).to have_current_path(expected_path)
  end
end
