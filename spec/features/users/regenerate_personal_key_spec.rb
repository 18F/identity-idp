require 'rails_helper'

feature 'View personal key' do
  include XPathHelper
  include PersonalKeyHelper
  include SamlAuthHelper

  context 'during sign up' do
    scenario 'user refreshes personal key page' do
      sign_up_and_view_personal_key

      visit sign_up_personal_key_path

      expect(current_path).to eq(account_path)
    end
  end

  context 'after sign up' do
    context 'regenerating personal key' do
      scenario 'displays new code' do
        user = sign_in_and_2fa_user
        old_code = user.personal_key

        click_button t('account.links.regenerate_personal_key')

        expect(user.reload.personal_key).to_not eq old_code
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code' do
        allow(Figaro.env).to receive(:reauthn_window).and_return('0')

        user = sign_in_and_2fa_user

        old_code = user.personal_key

        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))
        click_on(t('account.links.regenerate_personal_key'))

        expect(user.reload.personal_key).to_not eq old_code
      end
    end

    context 'personal key actions and information' do
      before do
        @user = sign_in_and_2fa_user
        click_button t('account.links.regenerate_personal_key')
      end

      it_behaves_like 'personal key page'
    end
  end

  context 'with javascript enabled', js: true do
    let(:invisible_selector) { generate_class_selector('invisible') }
    let(:accordion_control_selector) { generate_class_selector('accordion-header-controls') }

    it 'prompts the user to enter their personal key to confirm they have it' do
      sign_in_and_2fa_user
      click_button t('account.links.regenerate_personal_key')

      expect_accordion_content_to_be_hidden_by_default

      expand_accordion

      expect_accordion_content_to_become_visible

      click_acknowledge_personal_key

      expect_confirmation_modal_to_appear_with_first_code_field_in_focus

      press_shift_tab

      expect_back_button_to_be_in_focus

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

  it_behaves_like 'csrf error when asking for new personal key', :saml
  it_behaves_like 'csrf error when asking for new personal key', :oidc
end

def sign_up_and_view_personal_key
  allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  sign_up_and_set_password
  fill_in 'Phone', with: '202-555-1212'
  click_send_security_code
  click_submit_default
end

def expect_accordion_content_to_be_hidden_by_default
  expect(page).to have_xpath("//#{accordion_control_selector}")
  expect(page).not_to have_content(t('users.personal_key.help_text'))
  expect(page).to have_xpath(
    "//div[@id='personal-key-confirm'][@class='display-none']", visible: false
  )
end

def expand_accordion
  page.find('.accordion-header-controls').click
end

def expect_accordion_content_to_become_visible
  expect(page).to have_xpath("//#{accordion_control_selector}[@aria-expanded='true']")
  expect(page).to have_content(t('users.personal_key.help_text'))
end

def expect_confirmation_modal_to_appear_with_first_code_field_in_focus
  expect(page).not_to have_xpath("//div[@id='personal-key-confirm'][@class='display-none']")
  expect(page).not_to have_xpath("//#{invisible_selector}[@id='personal-key']")
  expect(page.evaluate_script('document.activeElement.name')).to eq 'personal_key'
end

def press_shift_tab
  body_element = page.find('body')
  body_element.send_keys %i[shift tab]
end

def expect_back_button_to_be_in_focus
  expect(page.evaluate_script('document.activeElement.innerText')).to eq(
    t('forms.buttons.back')
  )
end

def click_back_button
  click_on t('forms.buttons.back')
end

def expect_to_be_back_on_manage_personal_key_page_with_continue_button_in_focus
  expect(page).to have_xpath(
    "//div[@id='personal-key-confirm'][@class='display-none']", visible: false
  )
  expect(page.evaluate_script('document.activeElement.value')).to eq(
    t('forms.buttons.continue')
  )
end

def submit_form_without_entering_the_code
  click_on t('forms.buttons.continue'), class: 'personal-key-confirm'
end
