require 'rails_helper'

feature 'sign up with backup code' do
  it 'works' do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    sign_up_and_set_password

    select_2fa_option('sms')
    fill_in 'user_phone_form[phone]', with: '202-555-1111'
    click_send_security_code
    p page.body
    click_submit_default

    expect(current_path).to eq two_factor_options_path
  end

  it 'works for each code and refreshes the codes on the last one' do
    user = create(:user, :signed_up, :with_authentication_app, :with_backup_code)
    old_codes = user.backup_code_configurations.map(&:code)
    BackupCodeGenerator::NUMBER_OF_CODES.times do |index|
      signin(user.email, user.password)
      code = user.backup_code_configurations[index].code
      visit login_two_factor_backup_code_path
      fill_in :backup_code_verification_form_backup_code, with: code
      click_on 'Submit'
      if index == BackupCodeGenerator::NUMBER_OF_CODES - 1
        visit login_two_factor_backup_code_path
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
