require 'rails_helper'

feature 'View recovery code during sign up flow' do
  scenario 'user refreshes recovery code page' do
    sign_up_and_view_recovery_code

    visit sign_up_recovery_code_path

    expect(current_path).to eq(profile_path)
  end

  def sign_up_and_view_recovery_code
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    sign_up_and_set_password
    fill_in 'Phone', with: '202-555-1212'
    click_button t('forms.buttons.send_passcode')
    click_button t('forms.buttons.submit.default')
  end
end
