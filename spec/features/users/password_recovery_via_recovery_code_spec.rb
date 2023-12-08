require 'rails_helper'

RSpec.feature 'Password recovery via personal key' do
  include PersonalKeyHelper
  include IdvStepHelper
  include SamlAuthHelper
  include OidcAuthHelper
  include SpAuthHelper

  let(:user) { create(:user, :fully_registered) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  scenario 'resets password and reactivates profile with personal key', email: true do
    personal_key = personal_key_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)

    reset_password_and_sign_back_in(user, new_password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(current_path).to eq reactivate_account_path

    reactivate_profile(new_password, personal_key)

    expect(page).to have_content t('idv.messages.personal_key')
    expect(page).to have_content t('headings.account.verified_account')
  end

  scenario 'resets password and reactivates profile with no personal key', email: true, js: true do
    personal_key_from_pii(user, pii)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(current_path).to eq(reactivate_account_path)

    visit account_path

    expect(page).not_to have_content(t('headings.account.verified_account'))

    click_link t('account.index.reactivation.link')
    click_on t('links.account.reactivate.without_key')
    click_on t('forms.buttons.continue')
    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: new_password
    click_idv_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')

    visit account_path

    expect(page).to have_content(t('headings.account.verified_account'))
    expect(current_path).to eq(account_path)
  end

  scenario 'resets password, not allowed to use personal key as 2fa', email: true do
    _personal_key = personal_key_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    click_link t('two_factor_authentication.login_options_link_text')

    expect(page).
      to_not have_selector("label[for='two_factor_options_form_selection_personal_key']")
  end

  context 'account recovery alternative paths' do
    before do
      personal_key_from_pii(user, pii)
      trigger_reset_password_and_click_email_link(user.email)
      reset_password_and_sign_back_in(user, new_password)
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    scenario 'resets password, chooses to reverify on personal key entry page', email: true do
      click_on t('links.account.reactivate.with_key')
      click_on t('links.reverify')

      expect(current_path).to eq(idv_welcome_path)
    end

    scenario 'resets password, view modal and close it', email: true do
      click_on t('links.account.reactivate.without_key')
      click_on t('links.cancel')

      expect(page).not_to have_css('[role="dialog"]:not([hidden])')
    end
  end

  describe 'signing in as IAL1 with proofed account after resetting password' do
    it 'redirects to SP without prompting to reactivate account' do
      user = create(:user, :proofed)
      visit_idp_from_sp_with_ial1(:oidc)
      trigger_reset_password_and_click_email_link(user.email)
      fill_in t('forms.passwords.edit.labels.password'), with: new_password
      fill_in t('components.password_confirmation.confirm_label'),
              with: new_password
      click_button t('forms.passwords.edit.buttons.submit')
      fill_in_credentials_and_submit(user.email, new_password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      click_agree_and_continue

      expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')
    end
  end

  it_behaves_like 'signing in as IAL1 with personal key after resetting password', :saml
  it_behaves_like 'signing in as IAL1 with personal key after resetting password', :oidc
  it_behaves_like 'signing in as IAL2 after resetting password', :saml
  it_behaves_like 'signing in as IAL2 after resetting password', :oidc

  def reactivate_profile(password, personal_key)
    click_on t('links.account.reactivate.with_key')

    expect(current_path).to eq verify_personal_key_path

    fill_in 'personal_key', with: personal_key
    click_continue

    expect(current_path).to eq verify_password_path

    fill_in 'Password', with: password
    click_continue
  end
end
