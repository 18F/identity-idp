require 'rails_helper'

RSpec.feature 'Forced password change when password is compromised' do
  include SamlAuthHelper

  let(:user) { user_with_2fa }

  before do
    allow(FeatureManagement).to receive(:check_password_enabled?).and_return(true)
    allow(IdentityConfig.store)
      .to receive(:sign_in_password_compromised_percent_tested)
      .and_return(100)
    allow(PwnedPasswords::LookupPassword).to receive(:call).and_return(true)
    reload_ab_tests
  end

  after { reload_ab_tests }

  scenario 'user is forced to the manage password page after signing in' do
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(manage_password_path)
  end

  scenario 'user cannot navigate away to the account page until they change it' do
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(manage_password_path)

    visit account_path

    expect(page).to have_current_path(manage_password_path)
  end

  scenario 'user can reach the account page after changing the password' do
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(manage_password_path)

    allow(PwnedPasswords::LookupPassword).to receive(:call).and_return(false)

    new_password = 'a fresh uncompromised password'
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    fill_in t('components.password_confirmation.confirm_label'), with: new_password
    click_button t('forms.passwords.edit.buttons.submit')

    visit account_path

    expect(page).to have_current_path(account_path)
  end
end
