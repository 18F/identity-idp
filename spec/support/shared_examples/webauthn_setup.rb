shared_examples 'webauthn setup' do
  it 'allows a user to setup webauthn' do
    mock_webauthn_setup_challenge
    visit_webauthn_setup

    expect(current_path).to eq webauthn_setup_path

    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup

    expect_webauthn_setup_success
    expect(user.reload.webauthn_configurations.count).to eq(1)

    webauthn_configuration = user.webauthn_configurations.first

    expect(webauthn_configuration.credential_public_key).to eq(credential_public_key)
    expect(webauthn_configuration.credential_id).to eq(credential_id)
  end

  it 'renders an error if the challenge/secret is incorrect' do
    # Not calling `mock_challenge` here means the challenge won't match the signature that is set
    # when the button is pressed.
    visit_webauthn_setup

    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup

    expect_webauthn_setup_error
  end

  it 'renders an error if the hardware key button has not been pressed' do
    mock_webauthn_setup_challenge
    visit_webauthn_setup

    expect(current_path).to eq webauthn_setup_path

    mock_submit_without_pressing_button_on_hardware_key_on_setup

    expect_webauthn_setup_error
  end
end
