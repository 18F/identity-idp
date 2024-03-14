require 'rails_helper'

RSpec.feature 'sign up with backup code', allowed_extra_analytics: [:*] do
  include DocAuthHelper
  include SamlAuthHelper

  context 'with js', js: true do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    end

    it 'allows backup code only MFA configurations' do
      user = sign_up_and_set_password
      expect(page).to_not \
        have_content t('two_factor_authentication.login_options.backup_code_info')
      select_2fa_option('backup_code')

      expect(page).to have_link(t('components.download_button.label'))
      expect(current_path).to eq backup_code_setup_path

      click_continue
      click_continue

      expect(page).to have_content(t('forms.validation.required_checkbox'))

      check t('forms.backup_code.saved')
      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(current_path).to eq confirm_backup_codes_path
      expect(user.backup_code_configurations.count).to eq(10)

      click_continue

      expect(fake_analytics).to have_logged_event('User registration: complete')
      expect(page).to have_title(t('titles.account'))
    end
  end

  it 'works for each code and refreshes the codes on the last one' do
    user = create(:user, :fully_registered, :with_authentication_app)

    codes = BackupCodeGenerator.new(user).create

    BackupCodeGenerator::NUMBER_OF_CODES.times do |index|
      signin(user.email, user.password)
      visit login_two_factor_options_path
      expect(page).to \
        have_content t('two_factor_authentication.login_options.backup_code_info')
      visit login_two_factor_backup_code_path
      uncheck(t('forms.messages.remember_device'))
      fill_in :backup_code_verification_form_backup_code, with: codes[index]
      click_on 'Submit'
      if index == BackupCodeGenerator::NUMBER_OF_CODES - 1
        expect(current_path).to eq backup_code_refreshed_path
        expect(page).to have_content(t('forms.backup_code.title'))
        expect(page).to have_content(t('forms.backup_code.last_code'))
        expect(user.backup_code_configurations.count).to eq(10)
        click_on 'Continue'

        expect(page).to have_content(t('notices.backup_codes_configured'))
        expect(current_path).to eq account_path
        expect(user.backup_code_configurations.count).to eq(10)
      else
        expect(current_path).to eq account_path
        sign_out_user
      end
    end
  end

  it 'directs to SP after backup code confirmation' do
    visit_idp_from_sp_with_ial1(:oidc)
    sign_up_and_set_password
    select_2fa_option('backup_code')

    expect(page).to have_current_path(confirm_backup_codes_path)

    click_continue

    expect(current_path).to eq(sign_up_completed_path)
  end

  context 'when the user needs a backup code reminder' do
    let!(:user) { create(:user, :fully_registered, :with_authentication_app, :with_backup_code) }
    let!(:event) do
      create(:event, user: user, event_type: :sign_in_after_2fa, created_at: 9.months.ago)
    end

    it 'redirects the user to the backup code reminder url' do
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default

      expect(current_path).to eq backup_code_reminder_path
    end
  end

  def sign_out_user
    first(:button, t('links.sign_out')).click
  end
end
