require 'rails_helper'

feature 'setting up backup MFA on sign in' do
  before do
    allow(Figaro.env).to receive(:personal_key_assignment_disabled).and_return('true')
  end

  context 'a user only has 1 MFA method' do
    let(:user) { create(:user, :with_phone) }

    scenario 'the user is required to setup a backup MFA method' do
      sign_in_live_with_2fa(user)

      expect_back_mfa_setup_to_be_required

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('titles.account'))
    end
  end

  context 'a user has 2 MFA methods' do
    let(:user) { create(:user, :with_phone, :with_authentication_app) }

    scenario 'the user is not required to setup backup MFA' do
      sign_in_live_with_2fa(user)

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('titles.account'))
    end
  end

  context 'a user has an MFA method and a personal key' do
    let(:user) { create(:user, :with_phone, :with_personal_key) }

    scenario 'the user is not required to setup backup MFA' do
      sign_in_live_with_2fa(user)

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('titles.account'))
    end
  end

  def expect_back_mfa_setup_to_be_required
    expect(page).to have_current_path(two_factor_options_path)
    expect(page).to have_content t('two_factor_authentication.two_factor_choice')

    visit account_path

    expect(page).to have_current_path(two_factor_options_path)
    expect(page).to have_content t('two_factor_authentication.two_factor_choice')

    select_2fa_option('sms')
    fill_in 'user_phone_form[phone]', with: '202-555-1111'
    click_send_security_code
    click_submit_default
  end
end
