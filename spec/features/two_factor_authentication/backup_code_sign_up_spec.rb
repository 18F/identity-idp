require 'rails_helper'

feature 'sign up with backup code' do
  include DocAuthHelper
  include SamlAuthHelper

  it 'allows backup code only MFA configurations' do
    user = sign_up_and_set_password
    expect(page).to_not \
      have_content t('two_factor_authentication.login_options.backup_code_info')
    select_2fa_option('backup_code')

    expect(page).to have_link(t('forms.backup_code.download'))
    expect(current_path).to eq backup_code_setup_path

    click_on 'Continue'
    click_continue

    expect(page).to have_content(t('notices.backup_codes_configured'))
    expect(current_path).to eq account_path
    expect(user.backup_code_configurations.count).to eq(10)
  end

  it 'does not show download button on a mobile device' do
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)

    sign_up_and_set_password

    select_2fa_option('backup_code')

    expect(page).to_not have_link(t('forms.backup_code.download'))
  end

  it 'works for each code and refreshes the codes on the last one' do
    user = create(:user, :signed_up, :with_authentication_app)

    codes = BackupCodeGenerator.new(user).create

    BackupCodeGenerator::NUMBER_OF_CODES.times do |index|
      signin(user.email, user.password)
      visit login_two_factor_options_path
      expect(page).to \
        have_content t('two_factor_authentication.login_options.backup_code_info')
      visit login_two_factor_backup_code_path
      fill_in :backup_code_verification_form_backup_code, with: codes[index]
      click_on 'Submit'
      if index == BackupCodeGenerator::NUMBER_OF_CODES - 1
        expect(current_path).to eq backup_code_refreshed_path
        expect(page).to have_content(t('forms.backup_code.subtitle'))
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

  it 'directs backup code only users to the SP during sign up' do
    visit_idp_from_sp_with_ial1(:oidc)
    sign_up_and_set_password
    select_2fa_option('backup_code')
    click_continue

    expect(page).to have_current_path(sign_up_completed_path)

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  context 'when the user needs a backup code reminder' do
    let!(:user) { create(:user, :signed_up, :with_authentication_app, :with_backup_code) }
    let!(:event) do
      create(:event, user: user, event_type: :sign_in_after_2fa, created_at: 9.months.ago)
    end

    context 'without feature flag on (IdentityConfig.store.backup_code_reminder_redirect)' do
      it 'redirects the user to the account url' do
        sign_in_user(user)
        fill_in_code_with_last_totp(user)
        click_submit_default

        expect(current_path).to eq account_path
      end
    end

    context 'with the feature flag turned on (IdentityConfig.store.backup_code_reminder_redirect)' do
      before do
        allow(IdentityConfig.store).to receive(:backup_code_reminder_redirect).and_return(true)
      end

      it 'redirects the user to the backup code reminder url' do
        sign_in_user(user)
        fill_in_code_with_last_totp(user)
        click_submit_default

        expect(current_path).to eq backup_code_reminder_path
      end
    end
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
  end
end
