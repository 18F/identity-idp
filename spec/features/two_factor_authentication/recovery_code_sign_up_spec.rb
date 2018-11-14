require 'rails_helper'

feature 'sign up with recovery code', :js do
  it 'works' do
    sign_up_and_set_password
    select_2fa_option('recovery_code')
    click_on 'Continue'
    binding.pry
    puts 'Done!'
  end
end
