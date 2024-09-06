require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on account pages', :js do
  let(:user) do
    # Create an interesting user with various states that affect content shown on account pages
    create(
      :user,
      :proofed,
      :with_multiple_emails,
      # all mfas
      :with_authentication_app,
      :with_backup_code,
      :with_personal_key,
      :with_phone,
      :with_piv_or_cac,
      :with_webauthn,
      :with_webauthn_platform,
    )
  end

  before do
    visit root_path
    sign_in_and_2fa_user(user)
  end

  scenario '"Your account" path' do
    visit account_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '"Your authentication methods" path' do
    visit account_two_factor_authentication_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '"Your connected accounts" path' do
    visit account_connected_accounts_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '"History" path' do
    visit account_history_path

    expect_page_to_have_no_accessibility_violations(page)
  end
end
