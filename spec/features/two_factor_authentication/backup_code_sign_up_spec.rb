require 'rails_helper'

feature 'sign up with backup code', :js do
  it 'works' do
    sign_up_and_set_password
    select_2fa_option('backup_code')
    click_on 'Continue'
  end

  it 'works on signin with code' do
    user = create(:user, :signed_up)
    codes = BackupCodeGenerator.new(user).generate
    signin(user.email, user.password)
    fill_in :backup_code_verification_form_backup_code, with: codes.first
    click_on 'Submit'
  end

  it 'works for each code' do
    user = create(:user, :signed_up)
    codes = BackupCodeGenerator.new(user).generate
    n = BackupCodeGenerator::NUMBER_OF_CODES
    (0..(n - 2)).each do |index|
      code = codes[index]
      signin(user.email, user.password)
      fill_in :backup_code_verification_form_backup_code, with: code
      click_on 'Submit'
      click_on 'Sign out'
    end
  end
end
