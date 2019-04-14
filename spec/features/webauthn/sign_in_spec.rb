require 'rails_helper'

feature 'webauthn sign in' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
  end

  let(:webauthn_configuration) do
    create(
      :webauthn_configuration,
      credential_id: credential_id,
      credential_public_key: credential_public_key,
    )
  end
  let(:user) do
    create(:user, :with_backup_code, webauthn_configurations: [webauthn_configuration])
  end

  it 'allows the user to sign in if webauthn is successful' do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    mock_press_button_on_hardware_key_on_verification
    click_button t('forms.buttons.continue')

    expect(page).to have_current_path(account_path)
  end

  it 'does not allow the user to sign in if the challenge/secret is incorrect' do
    # Not calling `mock_challenge` here means the challenge won't match the signature that is set
    # when the button is pressed.
    sign_in_user(user)
    mock_press_button_on_hardware_key_on_verification
    click_button t('forms.buttons.continue')

    expect(page).to have_content(t('errors.invalid_authenticity_token'))
    expect(page).to have_current_path(login_two_factor_webauthn_path)
  end

  it 'does not allow the user to sign in if the hardware button has not been pressed' do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    click_button t('forms.buttons.continue')

    expect(page).to have_content(t('errors.invalid_authenticity_token'))
    expect(page).to have_current_path(login_two_factor_webauthn_path)
  end
end
