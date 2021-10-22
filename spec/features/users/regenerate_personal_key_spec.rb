require 'rails_helper'

feature 'View personal key' do
  include XPathHelper
  include PersonalKeyHelper
  include SamlAuthHelper

  let(:user) { create(:user, :signed_up, :with_personal_key) }

  context 'after sign up' do
    context 'regenerating personal key' do
      scenario 'displays new code and notifies the user' do
        sign_in_and_2fa_user(user)
        old_digest = user.encrypted_recovery_code_digest

        # The user should receive an SMS and an email
        personal_key_sign_in_mail = double
        expect(personal_key_sign_in_mail).to receive(:deliver_now_or_later)
        expect(UserMailer).to receive(:personal_key_regenerated).
          with(user, user.email).
          and_return(personal_key_sign_in_mail)
        expect(Telephony).to receive(:send_personal_key_regeneration_notice).
          with(to: user.phone_configurations.first.phone, country_code: 'US')

        visit account_two_factor_authentication_path
        click_button t('account.links.regenerate_personal_key')

        expect(user.reload.encrypted_recovery_code_digest).to_not eq old_digest
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code' do
        allow(IdentityConfig.store).to receive(:reauthn_window).and_return(0)

        sign_in_and_2fa_user(user)

        old_digest = user.encrypted_recovery_code_digest

        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))
        visit account_two_factor_authentication_path
        click_on(t('account.links.regenerate_personal_key'))

        expect(user.reload.encrypted_recovery_code_digest).to_not eq old_digest
      end
    end

    context 'personal key actions and information' do
      before do
        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path
        click_button t('account.links.regenerate_personal_key')
      end

      it_behaves_like 'personal key page'
    end
  end

  context 'with javascript enabled', js: true do
    it 'prompts the user to enter their personal key to confirm they have it' do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_button t('account.links.regenerate_personal_key')

      click_acknowledge_personal_key

      expect_confirmation_modal_to_appear_with_first_code_field_in_focus

      expect(page).to have_selector(:link_or_button, 'Back')

      click_back_button

      expect_to_be_back_on_manage_personal_key_page_with_continue_button_in_focus

      click_acknowledge_personal_key
      submit_form_without_entering_the_code

      expect(current_path).not_to eq account_path

      visit manage_personal_key_path

      acknowledge_and_confirm_personal_key

      expect(current_path).to eq account_path
    end

    it 'confirms personal key on mobile', driver: :headless_chrome_mobile do
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_button t('account.links.regenerate_personal_key')

      click_acknowledge_personal_key

      expect_confirmation_modal_to_appear_with_first_code_field_in_focus

      expect(page).to have_selector(:link_or_button, 'Back')

      click_back_button

      expect_to_be_back_on_manage_personal_key_page_with_continue_button_in_focus

      click_acknowledge_personal_key
      submit_form_without_entering_the_code

      expect(current_path).not_to eq account_path

      visit manage_personal_key_path
      acknowledge_and_confirm_personal_key

      expect(current_path).to eq account_path
    end
  end
end

def sign_up_and_view_personal_key
  sign_up_and_set_password
  select_2fa_option('phone')
  fill_in 'new_phone_form_phone', with: '202-555-1212'
  click_send_security_code
  fill_in_code_with_last_phone_otp
  click_submit_default
end

def expect_confirmation_modal_to_appear_with_first_code_field_in_focus
  expect(page).not_to have_xpath("//div[@id='personal-key-confirm'][@class='display-none']")
  expect(page.evaluate_script('document.activeElement.name')).to eq 'personal_key'
end

def click_back_button
  click_on t('forms.buttons.back')
end

def expect_to_be_back_on_manage_personal_key_page_with_continue_button_in_focus
  expect(page).to have_xpath(
    "//div[@id='personal-key-confirm'][@class='display-none']", visible: false
  )
  expect(page.evaluate_script('document.activeElement.value')).to eq(
    t('forms.buttons.continue'),
  )
end

def submit_form_without_entering_the_code
  click_on t('forms.buttons.continue'), class: 'personal-key-confirm'
end
