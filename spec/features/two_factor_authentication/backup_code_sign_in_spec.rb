require 'rails_helper'

RSpec.feature 'sign in with backup code' do
  include SamlAuthHelper
  include InteractionHelper
  include NavigationHelper

  let(:user) { create(:user) }
  let!(:codes) { BackupCodeGenerator.new(user).delete_and_regenerate }

  before do
    sign_in_before_2fa(user)
  end

  it 'allows the user to authenticate with a valid backup code' do
    fill_in t('forms.two_factor.backup_code'), with: codes.sample
    click_submit_default

    expect(page).to have_current_path(account_path)
  end

  it 'renders an error if the user enters an invalid backup code' do
    while codes.include?(code = ('a'..'z').to_a.sample(12).join); end
    fill_in t('forms.two_factor.backup_code'), with: code
    click_submit_default

    expect(page).to have_current_path(login_two_factor_backup_code_path)
    expect(page).to have_content(t('two_factor_authentication.invalid_backup_code'))
  end

  context 'with javascript enabled', :js do
    it 'validates input format before allowing submission' do
      input = page.find_field(t('forms.two_factor.backup_code'))

      # Validate empty field as required
      click_submit_default
      expect(input).to have_description(t('simple_form.required.text'))

      # Validate pattern mismatch
      input.fill_in with: 'wrong format'
      assert_navigation(false) { click_submit_default }
      expect(input).to have_description(t('two_factor_authentication.invalid_backup_code'))

      # Valid pattern should be submitted
      input.fill_in with: ''
      input.fill_in with: codes.sample.capitalize # Mixed capitalization
      assert_navigation { click_submit_default }
    end
  end

  context 'when the user needs a backup code reminder' do
    let(:user) do
      create(:user, :with_phone, created_at: 10.months.ago)
    end

    let!(:event) do
      create(:event, user:, event_type: :sign_in_after_2fa, created_at: 9.months.ago)
      create(:event, user:, event_type: :sign_in_after_2fa, created_at: 8.months.ago)
    end

    it 'redirects the user to the backup code reminder url and allows user to confirm possession' do
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(backup_code_reminder_path)

      click_on t('forms.backup_code_reminder.have_codes')

      expect(page).to have_current_path(account_path)
    end

    it 'redirects the user to the backup code reminder url and allows user to create new codes' do
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(backup_code_reminder_path)

      click_on t('forms.backup_code_reminder.need_new_codes')

      expect(page).to have_current_path(backup_code_regenerate_path)
    end

    context 'authenticating with backup code' do
      before do
        sign_in_before_2fa(user)
        choose_another_security_option(:backup_code)
        fill_in t('forms.two_factor.backup_code'), with: codes.sample
        click_submit_default
      end

      it 'does not prompt the user to confirm backup code possession' do
        expect(page).to have_current_path(account_path)
      end
    end

    context 'after dismissing the prompt (remembered device)' do
      before do
        fill_in_code_with_last_phone_otp
        check t('forms.messages.remember_device')
        click_submit_default
        click_on t('forms.backup_code_reminder.have_codes')
        click_on t('links.sign_out')
      end

      it 'does not prompt again the next sign in' do
        sign_in_before_2fa(user)

        expect(page).to have_current_path(account_path)
      end
    end

    context 'after dismissing the prompt (non-remembered device)' do
      before do
        fill_in_code_with_last_phone_otp
        uncheck t('forms.messages.remember_device')
        click_submit_default
        click_on t('forms.backup_code_reminder.have_codes')
        click_on t('links.sign_out')
      end

      it 'does not prompt again the next sign in' do
        sign_in_before_2fa(user)

        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(account_path)
      end
    end

    context 'when signing in to partner application' do
      before do
        visit_idp_from_sp_with_ial1(:oidc)
      end

      it 'redirects the user to backup code reminder url and allows user to confirm possession' do
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(backup_code_reminder_path)

        click_on t('forms.backup_code_reminder.have_codes')

        expect(page).to have_current_path(sign_up_completed_path)
      end

      it 'redirects the user to the backup code reminder url and allows user to create new codes' do
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(backup_code_reminder_path)
        click_on t('forms.backup_code_reminder.need_new_codes')

        expect(page).to have_current_path(backup_code_regenerate_path)
        click_on t('account.index.backup_code_confirm_regenerate')

        click_continue

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end
  end
end
