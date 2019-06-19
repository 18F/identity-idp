require 'rails_helper'

feature 'sign up with backup code' do
  include DocAuthHelper

  it 'works' do
    user = sign_up_and_set_password
    expect(FirstMfaEnabledForUser.call(user)).to eq(:error)
    select_2fa_option('backup_code')

    expect(page).to have_link(t('forms.backup_code.download'))
    expect(current_path).to eq backup_code_setup_path

    click_on 'Continue'

    expect(page).to have_selector('#two_factor_options_form_selection_backup_code_only', count: 1)
    expect(current_path).to eq two_factor_options_path
    expect(FirstMfaEnabledForUser.call(user)).to eq(:backup_code)
  end

  it 'does not show download button on a mobile device' do
    allow(DeviceDetector).to receive(:new).and_return(mobile_device)

    sign_up_and_set_password

    select_2fa_option('backup_code')

    expect(page).to_not have_link(t('forms.backup_code.download'))
  end

  it 'works for each code and refreshes the codes on the last one' do
    user = create(:user, :signed_up, :with_authentication_app, :with_backup_code)
    BackupCodeGenerator::NUMBER_OF_CODES.times do |index|
      signin(user.email, user.password)
      code = user.backup_code_configurations[index].code
      visit login_two_factor_backup_code_path
      fill_in :backup_code_verification_form_backup_code, with: code
      click_on 'Submit'
      if index == BackupCodeGenerator::NUMBER_OF_CODES - 1
        expect(current_path).to eq backup_code_setup_path
        expect(user.backup_code_configurations.count).to eq(0)

        click_on 'Continue'

        expect(current_path).to eq account_path
        expect(user.backup_code_configurations.count).to eq(10)
      else
        expect(current_path).to eq account_path
        sign_out_user
      end
    end
  end

  it 'allows backup code only MFA configurations' do
    user = sign_up_and_set_password

    expect(current_path).to eq two_factor_options_path
    select_2fa_option('backup_code')
    click_on 'Continue'

    expect(current_path).to eq two_factor_options_path
    expect(user.backup_code_configurations.count).to eq(10)
    select_2fa_option('backup_code_only')

    expect(current_path).to eq account_path
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
  end
end
