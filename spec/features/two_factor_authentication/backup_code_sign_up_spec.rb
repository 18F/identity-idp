require 'rails_helper'

feature 'sign up with backup code', :js do
  it 'works' do
    # binding.pry
    sign_up_and_set_password
    # binding.pry
    select_2fa_option('backup_code')
    # binding.pry
    click_on 'Continue'
    # binding.pry
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
      # binding.pry
      code = codes[index]
      signin(user.email, user.password)
      # binding.pry
      fill_in :backup_code_verification_form_backup_code, with: code
      # binding.pry
      click_on 'Submit'
      # binding.pry
      click_on 'Sign out'
    end
    signin(user.email, user.password)
  end
end
