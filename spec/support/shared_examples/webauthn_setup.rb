RSpec.shared_examples 'webauthn setup' do
  include WebAuthnHelper

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

  context 'platform authenticator logging' do
    before do
      allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(true)
      allow(IdentityConfig.store).
        to receive(:show_unsupported_passkey_platform_authentication_setup).
        and_return(true)
      allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      mock_webauthn_setup_challenge
    end

    let!(:user) { sign_up_and_set_password }
    let(:fake_analytics) { FakeAnalytics.new }

    it 'sends a submit failure event', :js do
      select_2fa_option('webauthn_platform', visible: :all)

      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_submit_without_pressing_button_on_hardware_key_on_setup
      expect(fake_analytics).to have_logged_event(
        :webauthn_setup_submitted,
        hash_including(success: false),
      )
    end

    it 'sends a submit success event', :js do
      select_2fa_option('webauthn_platform', visible: :all)
      expect(current_path).to eq webauthn_setup_path
      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup

      expect(fake_analytics).to have_logged_event(
        :webauthn_setup_submitted,
        hash_including(success: true),
      )
    end
  end
end
