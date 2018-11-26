require 'rails_helper'

feature 'sign up with recovery code', :js do
  it 'works' do
    sign_up_and_set_password
    select_2fa_option('recovery_code')
    click_on 'Continue'
    # binding.pry
    # puts 'Done!'
  end

  it 'works on signin' do
    user = create(:user, :signed_up)
    codes = RecoveryCodeGenerator.new(user).generate
    signin(user.email, user.password)
    # binding.pry
    fill_in :recovery_code_verification_form_recovery_code, with: codes.first
    click_on 'Submit'
    binding.pry
  end
end
