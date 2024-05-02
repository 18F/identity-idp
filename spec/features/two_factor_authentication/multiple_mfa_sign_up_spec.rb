require 'rails_helper'

RSpec.feature 'Multi Two Factor Authentication', allowed_extra_analytics: [:*] do
  include WebAuthnHelper

  describe 'When the user has not set up 2FA' do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    end

    scenario 'user can set up 2 MFA methods properly' do
      sign_up_and_set_password

      expect(page).to have_current_path authentication_methods_setup_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
        to have_content t('headings.add_info.phone')

      expect(page).to have_current_path phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path backup_code_setup_path

      expect(page).to have_link(t('components.download_button.label'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(fake_analytics).to have_logged_event('User registration: complete')
      expect(page).to have_current_path account_path
    end

    scenario 'user can select 2 MFA methods and then chooses another method during' do
      sign_up_and_set_password

      expect(page).to have_current_path authentication_methods_setup_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
        to have_content t('headings.add_info.phone')

      expect(page).to have_current_path phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path backup_code_setup_path

      click_button t('two_factor_authentication.choose_another_option')

      expect(page).to have_current_path(authentication_methods_setup_path)

      select_2fa_option('auth_app')

      fill_in_totp_name

      secret = find('#qr-code').text
      totp = generate_totp_code(secret)

      fill_in :code, with: totp
      check t('forms.messages.remember_device')
      click_submit_default

      expect(fake_analytics).to have_logged_event('User registration: complete')
      expect(page).to have_current_path account_path
    end

    scenario 'user can select 2 MFA methods and complete after reauthn window' do
      allow(IdentityConfig.store).to receive(:reauthn_window).and_return(10)
      sign_up_and_set_password

      expect(page).to have_current_path authentication_methods_setup_path

      click_2fa_option('backup_code')
      click_2fa_option('auth_app')

      click_continue

      expect(page).to have_current_path authenticator_setup_path

      fill_in_totp_name

      secret = find('#qr-code').text
      totp = generate_totp_code(secret)

      fill_in :code, with: totp
      check t('forms.messages.remember_device')
      click_submit_default

      expect(page).to have_current_path backup_code_setup_path
      travel_to((IdentityConfig.store.reauthn_window + 5).seconds.from_now) do
        click_continue

        expect(page).to have_content(t('notices.backup_codes_configured'))

        expect(page).to have_current_path account_path
      end
    end

    scenario 'user can select 1 MFA methods and will be prompted to add another method' do
      sign_in_before_2fa

      expect(page).to have_current_path authentication_methods_setup_path

      click_2fa_option('phone')

      click_continue

      expect(page).
        to have_content t('headings.add_info.phone')

      click_continue

      fill_in 'new_phone_form_phone', with: '301-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(
        auth_method_confirmation_path,
      )

      click_button t('mfa.skip')

      expect(page).to have_current_path account_path
    end

    describe 'skipping second mfa' do
      context 'with skippable mfa method' do
        it 'allows user to skip using skip link' do
          sign_up_and_set_password
          click_2fa_option('backup_code')

          click_continue
          expect(page).to have_current_path backup_code_setup_path

          expect(page).to have_link(t('components.download_button.label'))

          click_continue
          expect(page).to have_content(t('notices.backup_codes_configured'))
          expect(page).to have_current_path(confirm_backup_codes_path)

          click_link t('mfa.add')
          expect(page).to have_current_path(authentication_methods_setup_path)

          click_link t('mfa.skip')
          expect(page).to have_current_path(account_path)
        end

        it 'allows user to skip by clicking continue without selection' do
          sign_up_and_set_password
          click_2fa_option('backup_code')

          click_continue
          expect(page).to have_current_path backup_code_setup_path

          expect(page).to have_link(t('components.download_button.label'))

          click_continue
          expect(page).to have_content(t('notices.backup_codes_configured'))
          expect(page).to have_current_path(confirm_backup_codes_path)

          click_link t('mfa.add')
          expect(page).to have_current_path(authentication_methods_setup_path)

          click_continue
          expect(page).to have_current_path(account_path)
        end
      end

      context 'with platform authenticator as the first mfa' do
        it 'does not allow the user to skip selecting second mfa' do
          allow(IdentityConfig.store).
            to receive(:show_unsupported_passkey_platform_authentication_setup).
            and_return(true)
          mock_webauthn_setup_challenge
          user = sign_up_and_set_password
          user.password = Features::SessionHelper::VALID_PASSWORD
          expect(page).to have_current_path authentication_methods_setup_path
          # webauthn option is hidden in browsers that don't support it
          select_2fa_option('webauthn_platform', visible: :all)

          click_continue
          expect(page).to have_current_path webauthn_setup_path(platform: true)

          mock_press_button_on_hardware_key_on_setup
          expect(page).to have_current_path(auth_method_confirmation_path)
          expect(page).to_not have_button(t('mfa.skip'))

          click_link t('mfa.add')
          expect(page).to have_current_path(authentication_methods_setup_path)

          click_continue
          expect(page).to have_current_path(authentication_methods_setup_path)
          expect(page).to have_content(
            t('errors.two_factor_auth_setup.must_select_additional_option'),
          )
        end
      end
    end
  end

  context 'when backup codes are the only selected option' do
    let(:mfa) { MfaContext.new(user) }
    let(:user) { create(:user) }
    before do
      sign_up_and_set_password

      expect(page).to have_current_path authentication_methods_setup_path

      click_2fa_option('backup_code')

      click_continue

      expect(page).to have_current_path backup_code_setup_path

      expect(page).to have_link(t('components.download_button.label'))
    end

    it 'shows the confirm backup codes page' do
      click_continue

      expect(page).to have_current_path(
        confirm_backup_codes_path,
      )
    end

    it 'goes to the next page after user confirms that they have saved their backup codes' do
      click_continue
      expect(page).to have_current_path(
        confirm_backup_codes_path,
      )

      click_continue
      expect(page).to have_current_path account_path
    end

    it 'returns to setup mfa page when user clicks Choose another option' do
      click_on(t('two_factor_authentication.choose_another_option'))
      expect(current_path).to eq authentication_methods_setup_path
      expect(mfa.backup_code_configurations).to be_empty
    end
  end

  describe 'adding a phone as a second mfa' do
    it 'at setup, phone as second MFA show a cancel link that returns to mfa setup' do
      allow(IdentityConfig.store).
        to receive(:show_unsupported_passkey_platform_authentication_setup).
        and_return(true)

      sign_up_and_set_password
      mock_webauthn_setup_challenge
      select_2fa_option('webauthn_platform', visible: :all)

      click_continue

      mock_press_button_on_hardware_key_on_setup

      click_link t('mfa.add')

      select_2fa_option('phone')
      click_continue

      fill_in :new_phone_form_phone, with: '3015551212'
      click_send_one_time_code

      expect(page).to have_link(
        t('links.cancel'),
        href: authentication_methods_setup_path,
      )
    end
  end

  def click_2fa_option(option)
    find("label[for='two_factor_options_form_selection_#{option}']").click
  end
end
