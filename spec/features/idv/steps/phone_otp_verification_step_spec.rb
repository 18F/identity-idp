require 'rails_helper'

feature 'phone otp verification step spec', :idv_job do
  include IdvStepHelper

  it 'requires the user to enter the correct otp before continuing' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step(user)

    # Attempt to bypass the step
    visit idv_review_path
    expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

    # Enter an incorrect otp
    fill_in 'code', with: '000000'
    click_submit_default

    expect(page).to have_content(t('devise.two_factor_authentication.invalid_otp'))
    expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

    # Enter the correct code
    enter_correct_otp_code_for_user(user)

    expect(page).to have_content(t('idv.titles.session.review'))
    expect(page).to have_current_path(idv_review_path)
  end

  it_behaves_like 'cancel at idv step', :phone_otp_verification
  it_behaves_like 'cancel at idv step', :phone_otp_verification, :oidc
  it_behaves_like 'cancel at idv step', :phone_otp_verification, :saml
end
