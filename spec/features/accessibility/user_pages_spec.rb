require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on pages that require authentication', :js do
  scenario 'user registration page' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(current_path).to eq(sign_up_verify_email_path)
    # We can't validate markup here, since markup validation requires a page reload when using the
    # JS driver, but the sign up verify email path can only be visited once before redirecting to
    # the account creation form. Instead, we validate markup separately with the non-JS driver.
    expect_page_to_have_no_accessibility_violations(page, validate_markup: false)
  end

  context 'with javascript disabled', js: false do
    scenario 'user registration page' do
      email = 'test@example.com'
      sign_up_with(email)

      expect(current_path).to eq(sign_up_verify_email_path)
      expect(page).to have_valid_markup
    end
  end

  describe 'user confirmation page' do
    scenario 'valid confirmation token' do
      create(:user, :unconfirmed)
      confirm_last_user

      expect(current_path).to eq(sign_up_enter_password_path)
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'invalid confirmation token' do
      visit sign_up_create_email_confirmation_path(confirmation_token: '123456')

      expect(current_path).to eq(sign_up_email_resend_path)
      expect_page_to_have_no_accessibility_violations(page)
    end
  end

  describe '2FA pages' do
    scenario 'two factor options page' do
      sign_up_and_set_password

      expect(current_path).to eq(authentication_methods_setup_path)
      expect_page_to_have_no_accessibility_violations(page)
      phone_checkbox = page.find_field('two_factor_options_form_selection_phone', visible: :all)
      expect(phone_checkbox).to have_name(
        t('two_factor_authentication.two_factor_choice_options.phone'),
      )
      expect(phone_checkbox).to have_description(
        t('two_factor_authentication.two_factor_choice_options.phone_info'),
      )
    end

    scenario 'phone setup page' do
      sign_up_and_set_password
      find("label[for='two_factor_options_form_selection_phone']").click
      click_button t('forms.buttons.continue')

      expect(current_path).to eq(phone_setup_path)
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'two factor auth page' do
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect_page_to_have_no_accessibility_violations(page)
    end

    describe 'SMS' do
      scenario 'enter 2fa phone OTP code page' do
        user = create(:user, :with_phone, with: { phone: '+1 (202) 555-1212' })
        sign_in_before_2fa(user)
        visit login_two_factor_path(otp_delivery_preference: 'sms')

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
        expect_page_to_have_no_accessibility_violations(page)
      end
    end

    describe 'Voice' do
      scenario 'enter 2fa phone OTP code page' do
        user = create(:user, :with_phone, with: { phone: '+1 (202) 555-1212' })
        sign_in_before_2fa(user)
        visit login_two_factor_path(otp_delivery_preference: 'voice')

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')
        expect_page_to_have_no_accessibility_violations(page)
      end
    end
  end

  scenario 'personal key page' do
    sign_in_and_2fa_user
    visit manage_personal_key_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'profile page' do
    sign_in_and_2fa_user

    visit account_path

    expect_page_to_have_no_accessibility_violations(page)
    expect_page_to_have_skip_link(page) do
      expect(page.active_element).to match_css('a', text: t('account.index.email_add'), wait: 5)
    end
  end

  scenario 'delete email page' do
    user = create(:user)
    sign_in_and_2fa_user(user)

    visit manage_email_confirm_delete_path(id: user.email_addresses.take.id)

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'edit password page' do
    sign_in_and_2fa_user

    visit manage_password_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'edit email language page' do
    sign_in_and_2fa_user

    visit account_email_language_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'add phone page' do
    sign_in_and_2fa_user

    visit phone_setup_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'edit phone page' do
    user = sign_in_and_2fa_user

    visit manage_phone_path(id: user.phone_configurations.first.id)

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'generate new personal key page' do
    sign_in_and_2fa_user

    visit manage_personal_key_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'set up authenticator app page' do
    sign_in_and_2fa_user

    visit '/authenticator_setup'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'device events page' do
    user = sign_in_and_2fa_user
    device = create(:device, user: user)
    create(:event, user: user)

    visit account_events_path(id: device.id)

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'delete user page' do
    sign_in_and_2fa_user

    visit account_delete_path

    expect_page_to_have_no_accessibility_violations(page)
  end
end
