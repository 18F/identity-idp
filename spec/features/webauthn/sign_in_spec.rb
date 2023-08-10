require 'rails_helper'

RSpec.feature 'webauthn sign in' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
  end

  let(:user) { create(:user, :with_webauthn, with: { credential_id:, credential_public_key: }) }
  let(:general_error) do
    t(
      'two_factor_authentication.webauthn_error.connect_html',
      link_html: t('two_factor_authentication.webauthn_error.additional_methods_link'),
    )
  end

  it 'allows the user to sign in if webauthn is successful' do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    mock_successful_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to have_current_path(account_path)
  end

  it 'does not allow the user to sign in if the challenge/secret is incorrect' do
    # Not calling `mock_challenge` here means the challenge won't match the signature that is set
    # when the button is pressed.
    sign_in_user(user)
    mock_successful_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to have_content(general_error)
    expect(page).to have_current_path(login_two_factor_webauthn_path)
  end

  it 'does not allow the user to sign in if the hardware button has not been pressed' do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    mock_cancelled_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to have_content(general_error)
    expect(page).to have_current_path(login_two_factor_webauthn_path)
  end

  it 'does not show error after successful challenge/secret reattempt', :js do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    mock_cancelled_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to have_content(general_error)

    mock_successful_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to_not have_content(general_error)
  end

  it 'maintains correct platform attachment content if cancelled', :js do
    mock_webauthn_verification_challenge

    sign_in_user(user)
    mock_cancelled_webauthn_authentication { click_webauthn_authenticate_button }

    expect(page).to have_content(t('two_factor_authentication.webauthn_header_text'))
  end

  context 'platform authenticator' do
    let(:user) do
      create(:user, :with_webauthn_platform, with: { credential_id:, credential_public_key: })
    end

    it 'maintains correct platform attachment content if cancelled', :js do
      mock_webauthn_verification_challenge

      sign_in_user(user)
      mock_cancelled_webauthn_authentication { click_webauthn_authenticate_button }

      expect(page).to have_content(t('two_factor_authentication.webauthn_platform_header_text'))
    end
  end
end
