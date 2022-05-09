require 'rails_helper'

feature 'A user with a UAK passwords attempts IdV' do
  include IdvStepHelper

  it 'allows the user to continue to the SP', js: true do
    user = user_with_2fa
    user.update!(
      encrypted_password_digest: Encryption::UakPasswordVerifier.digest(user.password),
    )

    start_idv_from_sp(:oidc)
    complete_idv_steps_with_phone_before_confirmation_step(user)

    acknowledge_and_confirm_personal_key

    expect(page).to have_current_path(sign_up_completed_path)

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end
end
