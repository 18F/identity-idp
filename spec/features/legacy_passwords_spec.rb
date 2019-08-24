require 'rails_helper'

feature 'legacy passwords' do
  scenario 'signing in with a password digested by the uak verifier updates the digest' do
    user = create(:user, :signed_up)
    user.update!(
      encrypted_password_digest: Encryption::UakPasswordVerifier.digest('legacy password'),
    )

    expect(
      Encryption::PasswordVerifier.new.stale_digest?(user.encrypted_password_digest),
    ).to eq(true)

    signin(user.email, 'legacy password')

    expect(page).to have_current_path(
      login_otp_path(otp_delivery_preference: :sms, reauthn: false),
    )
    expect(page).to have_content(t('two_factor_authentication.header_text'))
    expect(
      Encryption::PasswordVerifier.new.stale_digest?(user.reload.encrypted_password_digest),
    ).to eq(false)
  end

  scenario 'signing in with an incorrect uak password digest does not grant access' do
    user = create(:user, :signed_up)
    user.update!(
      encrypted_password_digest: Encryption::UakPasswordVerifier.digest('legacy password'),
    )

    signin(user.email, 'a different password')

    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_content(
      t('devise.failure.invalid_html', link: t('devise.failure.invalid_link_text')),
    )
  end

  scenario 'signing in with a personal key digested by the uak verifier make the digest nil' do
    user = create(:user, :signed_up)
    user.update!(
      encrypted_recovery_code_digest: Encryption::UakPasswordVerifier.digest('1111 2222 3333 4444'),
    )

    expect(
      Encryption::PasswordVerifier.new.stale_digest?(user.encrypted_recovery_code_digest),
    ).to eq(true)

    sign_in_user(user)
    visit login_two_factor_personal_key_path
    fill_in :personal_key_form_personal_key, with: '1111222233334444'
    click_submit_default
    user.reload

    expect(user.encrypted_recovery_code_digest).to be_nil
  end

  scenario 'signing in with an incorrect uak personal key digest does not grant access' do
    user = create(:user, :signed_up)
    user.update!(
      encrypted_recovery_code_digest: Encryption::UakPasswordVerifier.digest('1111 2222 3333 4444'),
    )

    sign_in_user(user)
    visit login_two_factor_personal_key_path
    fill_in :personal_key_form_personal_key, with: '1111 1111 1111 1111'
    click_submit_default

    expect(page).to have_current_path(login_two_factor_personal_key_path)
    expect(page).to have_content(t('two_factor_authentication.invalid_personal_key'))
  end
end
