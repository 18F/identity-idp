require 'rails_helper'

feature 'View recovery code' do
  include XPathHelper
  include RecoveryCodeHelper

  context 'during sign up' do
    scenario 'user refreshes recovery code page' do
      sign_up_and_view_recovery_code

      visit sign_up_recovery_code_path

      expect(current_path).to eq(profile_path)
    end
  end

  context 'after sign up' do
    context 'regenerating recovery code' do
      scenario 'displays new code' do
        user = sign_in_and_2fa_user
        old_code = user.recovery_code

        click_link t('profile.links.regenerate_recovery_code')

        expect(user.reload.recovery_code).to_not eq old_code
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code' do
        allow(Figaro.env).to receive(:reauthn_window).and_return('0')

        user = sign_in_and_2fa_user

        old_code = user.recovery_code

        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))
        click_on(t('profile.links.regenerate_recovery_code'))

        expect(user.reload.recovery_code).to_not eq old_code
      end
    end

    context 'recovery code actions and information' do
      before do
        @user = sign_in_and_2fa_user
        click_link t('profile.links.regenerate_recovery_code')
      end

      it_behaves_like 'recovery code page'
    end
  end

  context 'with javascript enabled', js: true do
    let(:invisible_selector) { generate_class_selector('invisible') }
    let(:accordion_control_selector) { generate_class_selector('accordion-header-control') }

    it 'prompts the user to enter their personal key to confirm they have it' do
      sign_in_and_2fa_user
      click_link t('profile.links.regenerate_recovery_code')

      expect_accordion_content_to_be_hidden_by_default

      expand_accordion

      expect_accordion_content_to_become_visible

      click_acknowledge_recovery_code

      expect_confirmation_modal_to_appear_with_first_code_field_in_focus

      press_shift_tab

      expect_back_button_to_be_in_focus

      click_back_button

      expect_to_be_back_on_manage_recovery_code_page_with_continue_button_in_focus

      click_acknowledge_recovery_code
      submit_form_without_entering_the_code

      expect(current_path).not_to eq profile_path

      visit manage_recovery_code_path
      acknowledge_and_confirm_recovery_code

      expect(current_path).to eq profile_path
    end
  end
end

def sign_up_and_view_recovery_code
  allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  sign_up_and_set_password
  fill_in 'Phone', with: '202-555-1212'
  click_send_security_code
  click_submit_default
end

def expect_accordion_content_to_be_hidden_by_default
  expect(page).to have_xpath("//#{accordion_control_selector}")
  expect(page).not_to have_content(t('users.recovery_code.help_text'))
  expect(page).to have_xpath(
    "//div[@id='personal-key-confirm'][@class='display-none']", visible: false
  )
end

def expand_accordion
  page.find('.accordion-header-control').click
end

def expect_accordion_content_to_become_visible
  expect(page).to have_xpath("//#{accordion_control_selector}[@aria-expanded='false']")
  expect(page).to have_content(t('users.recovery_code.help_text'))
end

def expect_confirmation_modal_to_appear_with_first_code_field_in_focus
  expect(page).not_to have_xpath("//div[@id='personal-key-confirm'][@class='display-none']")
  expect(page).not_to have_xpath("//#{invisible_selector}[@id='recovery-code']")
  expect(page.evaluate_script('document.activeElement.name')).to eq 'recovery-0'
end

def press_shift_tab
  body_element = page.find('body')
  body_element.send_keys [:shift, :tab]
end

def expect_back_button_to_be_in_focus
  expect(page.evaluate_script('document.activeElement.innerText')).to eq(
    t('forms.buttons.back')
  )
end

def click_back_button
  click_on t('forms.buttons.back')
end

def expect_to_be_back_on_manage_recovery_code_page_with_continue_button_in_focus
  expect(page).to have_xpath(
    "//div[@id='personal-key-confirm'][@class='display-none']", visible: false
  )
  expect(page.evaluate_script('document.activeElement.value')).to eq(
    t('forms.buttons.continue')
  )
end

def submit_form_without_entering_the_code
  click_on t('forms.buttons.continue'), class: 'recovery-code-confirm'
end
