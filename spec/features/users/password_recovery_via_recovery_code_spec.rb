require 'rails_helper'

feature 'Password recovery via recovery code' do
  include RecoveryCodeHelper

  let(:user) { create(:user, :signed_up) }
  let(:new_password) { 'some really awesome new password' }
  let(:pii) { { ssn: '666-66-1234', dob: '1920-01-01' } }

  scenario 'resets password and reactivates profile with recovery code', email: true do
    recovery_code = recovery_code_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)

    reset_password_and_sign_back_in(user, new_password)
    click_submit_default
    enter_correct_otp_code_for_user(user)

    expect(current_path).to eq reactivate_profile_path

    reactivate_profile(new_password, recovery_code)

    expect(page).to have_content t('idv.messages.recovery_code')
  end

  scenario 'resets password, makes recovery code, attempts reactivate profile', email: true do
    _recovery_code = recovery_code_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)

    reset_password_and_sign_back_in(user, new_password)
    click_submit_default
    enter_correct_otp_code_for_user(user)

    expect(current_path).to eq reactivate_profile_path

    visit manage_recovery_code_path

    new_recovery_code = scrape_recovery_code
    click_acknowledge_recovery_code

    expect(current_path).to eq reactivate_profile_path

    reactivate_profile(new_password, new_recovery_code)

    expect(page).to have_content t('errors.messages.recovery_code_incorrect')
  end

  scenario 'resets password, uses recovery code as 2fa', email: true do
    recovery_code = recovery_code_from_pii(user, pii)

    trigger_reset_password_and_click_email_link(user.email)

    reset_password_and_sign_back_in(user, new_password)
    click_submit_default

    click_link t('devise.two_factor_authentication.recovery_code_fallback.link')

    enter_recovery_code(code: recovery_code)

    click_submit_default

    expect(current_path).to eq sign_up_recovery_code_path

    new_recovery_code = scrape_recovery_code
    click_acknowledge_recovery_code

    expect(current_path).to eq reactivate_profile_path

    reactivate_profile(new_password, new_recovery_code)

    expect(page).to_not have_content t('errors.messages.recovery_code_incorrect')
    expect(page).to have_content t('idv.messages.recovery_code')
  end

  def scrape_recovery_code
    new_recovery_code_words = []
    page.all(:css, '[data-recovery]').each do |node|
      new_recovery_code_words << node.text
    end
    new_recovery_code_words.join(' ')
  end

  def reactivate_profile(password, recovery_code)
    fill_in 'Password', with: password
    enter_recovery_code(code: recovery_code)
    click_button t('forms.reactivate_profile.submit')
  end
end
