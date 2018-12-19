require 'rails_helper'

feature 'sign up with backup code' do
  it 'works' do
    sign_up_and_set_password
    select_2fa_option('backup_code')

    expect(current_path).to eq backup_code_setup_path

    click_on 'Continue'

    expect(current_path).to eq sign_up_personal_key_path
  end

  it 'works for each code and refreshes the codes on the last one' do
    user = create(:user, :with_backup_code)
    old_codes = user.backup_code_configurations.map(&:code)
    BackupCodeGenerator::NUMBER_OF_CODES.times do |index|
      signin(user.email, user.password)
      code = user.backup_code_configurations[index].code
      fill_in :backup_code_verification_form_backup_code, with: code
      click_on 'Submit'
      if index == BackupCodeGenerator::NUMBER_OF_CODES - 1
        expect(current_path).to eq backup_code_setup_path
        user.reload
        new_codes = user.backup_code_configurations.map(&:code)
        expect(new_codes & old_codes).to eq([])
      else
        expect(current_path).to eq account_path
        sign_out_user
      end
    end
  end

  def sign_out_user
    first(:link, t('links.sign_out')).click
  end
end
