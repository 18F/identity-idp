require 'rails_helper'

feature 'Password recovery via personal key', idv_job: true do
  include PersonalKeyHelper
  include IdvHelper
  include SamlAuthHelper
  include SpAuthHelper

  let(:user) { create(:user, :signed_up) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' } }

  scenario 'resets password and reactivates profile with personal key', email: true, js: true do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

    personal_key = personal_key_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)

    reset_password_and_sign_back_in(user, new_password)
    click_submit_default

    expect(current_path).to eq reactivate_account_path

    reactivate_profile(new_password, personal_key)

    expect(page).to have_content t('idv.messages.personal_key')
    expect(page).to have_content t('headings.account.verified_account')
  end

  scenario 'resets password and reactivates profile with no personal key', email: true, js: true do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    personal_key_from_pii(user, pii)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    click_submit_default

    expect(current_path).to eq(reactivate_account_path)

    visit account_path

    expect(page).not_to have_content(t('headings.account.verified_account'))

    click_link t('account.index.reactivation.link')
    click_on t('links.account.reactivate.without_key')
    click_on t('forms.buttons.continue')
    click_idv_begin
    complete_idv_profile_ok(user, new_password)
    acknowledge_and_confirm_personal_key

    expect(page).to have_content(t('headings.account.verified_account'))
    expect(current_path).to eq(account_path)
  end

  scenario 'resets password, uses personal key as 2fa', email: true do
    personal_key = personal_key_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    click_link t('devise.two_factor_authentication.personal_key_fallback.link')
    enter_personal_key(personal_key: personal_key)
    click_submit_default

    expect(current_path).to eq manage_personal_key_path

    new_personal_key = scrape_personal_key
    click_acknowledge_personal_key

    expect(current_path).to eq reactivate_account_path

    reactivate_profile(new_password, new_personal_key)

    expect(page).to_not have_content t('errors.messages.personal_key_incorrect')
    expect(page).to have_content t('idv.messages.personal_key')
    expect(page).to have_current_path(account_path)
  end

  context 'account recovery alternative paths' do
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      personal_key_from_pii(user, pii)
      trigger_reset_password_and_click_email_link(user.email)
      reset_password_and_sign_back_in(user, new_password)
      click_submit_default
    end

    scenario 'resets password, chooses to reverify on personal key entry page', email: true do
      click_on t('links.account.reactivate.with_key')
      click_on t('links.reverify')

      expect(current_path).to eq(idv_path)
    end

    scenario 'resets password, view modal and close it', email: true, js: true do
      click_on t('links.account.reactivate.without_key')
      click_on t('links.cancel')

      expect(page).not_to have_content('[id="reactivate-account-modal"]')
    end
  end

  it_behaves_like 'signing in as LOA1 with personal key after resetting password', :saml
  it_behaves_like 'signing in as LOA1 with personal key after resetting password', :oidc
  it_behaves_like 'signing in as LOA3 with personal key after resetting password', :saml
  it_behaves_like 'signing in as LOA3 with personal key after resetting password', :oidc

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
