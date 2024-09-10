require 'rails_helper'

RSpec.feature 'sign in with backup code' do
  include InteractionHelper

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
end
