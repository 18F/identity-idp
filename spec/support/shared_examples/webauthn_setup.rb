RSpec.shared_examples 'webauthn setup' do
  it 'allows a user to setup webauthn' do
    mock_webauthn_setup_challenge
    visit_webauthn_setup

    expect(page).to have_current_path webauthn_setup_path

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

    expect(page).to have_current_path webauthn_setup_path

    mock_submit_without_pressing_button_on_hardware_key_on_setup

    expect_webauthn_setup_error
  end

  context 'platform authenticator logging' do
    let!(:user) { sign_up_and_set_password }
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow(IdentityConfig.store)
        .to receive(:show_unsupported_passkey_platform_authentication_setup)
        .and_return(true)
      allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      mock_webauthn_setup_challenge
    end

    it 'sends a submit failure event', :js do
      select_2fa_option('webauthn', visible: :all)

      fill_in_nickname_and_click_continue
      mock_submit_without_pressing_button_on_hardware_key_on_setup
      expect(fake_analytics).to have_logged_event(
        :webauthn_setup_submitted,
        errors: { SecurityError:
          [
            t(
              'errors.webauthn_setup.general_error_html',
              link_html: link_to(
                t('errors.webauthn_setup.additional_methods_link'),
                authentication_methods_setup_path,
              ),
            ),
          ] },
        platform_authenticator: false,
        success: false,
      )
    end

    it 'sends a submit success event', :js do
      select_2fa_option('webauthn', visible: :all)

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup

      expect(fake_analytics).to have_logged_event(
        :webauthn_setup_submitted,
        success: true,
        platform_authenticator: false,
      )
    end
  end
end
