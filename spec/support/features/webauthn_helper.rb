module WebAuthnHelper
  include JavascriptDriverHelper
  include ActionView::Helpers::UrlHelper

  def mock_webauthn_setup_challenge
    allow(WebAuthn::Credential).to receive(:options_for_create).and_return(
      instance_double(
        WebAuthn::PublicKeyCredential::CreationOptions,
        challenge: webauthn_challenge.pack('c*'),
      ),
    )
  end

  def mock_webauthn_verification_challenge
    allow(WebAuthn::Credential).to receive(:options_for_get).and_return(
      instance_double(
        WebAuthn::PublicKeyCredential::RequestOptions,
        challenge: webauthn_challenge.pack('c*'),
      ),
    )
  end

  def fill_in_nickname_and_click_continue(nickname: 'mykey')
    fill_in 'name', with: nickname
  end

  def mock_submit_without_pressing_button_on_hardware_key_on_setup
    first('#continue-button').click
  end

  def mock_press_button_on_hardware_key_on_setup
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    # simulate javascript that is triggered when the hardware key button is pressed
    set_hidden_field('webauthn_id', webauthn_id)
    set_hidden_field('webauthn_public_key', webauthn_public_key)
    set_hidden_field('attestation_object', attestation_object)
    set_hidden_field('client_data_json', setup_client_data_json)

    button = first('#continue-button')
    if javascript_enabled?
      page.evaluate_script('document.querySelector("form").submit()')
    else
      button.click
    end
  end

  def mock_cancelled_webauthn_authentication
    if javascript_enabled?
      page.evaluate_script(<<~JS)
        navigator.credentials.get = () => Promise.reject(new DOMException('', 'NotAllowedError'));
      JS

      yield

      if platform_authenticator?
        expect(page).to have_content(
          strip_tags(
            t(
              'two_factor_authentication.webauthn_error.try_again',
              link: link_to(
                t('two_factor_authentication.webauthn_error.additional_methods_link'),
                login_two_factor_options_path,
              ),
            ),
          ),
          wait: 5,
        )
      else
        expect(page).to have_content(t('errors.general'), wait: 5)
      end
    else
      yield
    end
  end

  def mock_successful_webauthn_authentication
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    if javascript_enabled?
      page.evaluate_script(<<~JS)
        base64ToArrayBuffer = (base64) => Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)).buffer;
      JS
      page.evaluate_script(<<~JS)
        navigator.credentials.get = () => Promise.resolve({
          rawId: base64ToArrayBuffer(#{credential_id.to_json}),
          response: {
            authenticatorData: base64ToArrayBuffer(#{authenticator_data.to_json}),
            clientDataJSON: base64ToArrayBuffer(#{verification_client_data_json.to_json}),
            signature: base64ToArrayBuffer(#{signature.to_json}),
          },
        });
      JS
      original_path = current_path
      yield
      expect(page).not_to have_current_path(original_path, wait: 5)
    else
      # simulate javascript that is triggered when the hardware key button is pressed
      set_hidden_field('credential_id', credential_id)
      set_hidden_field('authenticator_data', authenticator_data)
      set_hidden_field('signature', signature)
      set_hidden_field('client_data_json', verification_client_data_json)

      yield
    end
  end

  def click_webauthn_authenticate_button
    if platform_authenticator?
      click_button t('two_factor_authentication.webauthn_platform_use_key')
    else
      click_button t('two_factor_authentication.webauthn_use_key')
    end
  end

  def set_hidden_field(id, value)
    input = first("input##{id}", visible: false)
    if javascript_enabled?
      input.execute_script("this.value = #{value.to_json}")
    else
      input.set(value)
    end
  end

  def protocol
    'http://'
  end

  def webauthn_challenge
    [130, 189, 118, 175, 4, 84, 80, 118, 106, 163, 161, 68, 35, 246, 37, 2]
  end

  def webauthn_id
    'ufhgW+5bCVo1N4lGCfTHjBfj1Z0ED8uTj4qys4WJzkgZunHEbx3ixuc1kLG6QTGes6lg+hbXRHztVh4eiDXoLg=='
  end

  def webauthn_public_key
    'ufhgW-5bCVo1N4lGCfTHjBfj1Z0ED8uTj4qys4WJzkgZunHEbx3ixuc1kLG6QTGes6lg-hbXRHztVh4eiDXoLg'
  end

  def credential_public_key
    <<~HEREDOC.delete("\n")
      pQECAyYgASFYIK13HTAGHERhmNxxkecMx0B+rTnzavDiu4yu1rXZltqOIlgg4AMQhEwL7gBzOs
      C7v0RAsYGjjeVmhGnag75HsrwruOA=
    HEREDOC
  end

  def attestation_object
    <<~HEREDOC
      o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVjESZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmV
      zzuoMdl2NBAAAAcAAAAAAAAAAAAAAAAAAAAAAAQLn4YFvuWwlaNTeJRgn0x4wX49WdBA/Lk4+K
      srOFic5IGbpxxG8d4sbnNZCxukExnrOpYPoW10R87VYeHog16C6lAQIDJiABIVggrXcdMAYcRG
      GY3HGR5wzHQH6tOfNq8OK7jK7WtdmW2o4iWCDgAxCETAvuAHM6wLu/RECxgaON5WaEadqDvkey
      vCu44A==
    HEREDOC
  end

  def setup_client_data_json
    <<~HEREDOC
      eyJjaGFsbGVuZ2UiOiJncjEycndSVVVIWnFvNkZFSV9ZbEFnIiwibmV3X2tleXNfbWF5X2JlX2
      FkZGVkX2hlcmUiOiJkbyBub3QgY29tcGFyZSBjbGllbnREYXRhSlNPTiBhZ2FpbnN0IGEgdGVt
      cGxhdGUuIFNlZSBodHRwczovL2dvby5nbC95YWJQZXgiLCJvcmlnaW4iOiJodHRwOi8vbG9jYW
      xob3N0OjMwMDAiLCJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0=
    HEREDOC
  end

  def verification_client_data_json
    <<~HEREDOC
      eyJjaGFsbGVuZ2UiOiJncjEycndSVVVIWnFvNkZFSV9ZbEFnIiwibmV3X2tleXNfbWF5X2JlX2
      FkZGVkX2hlcmUiOiJkbyBub3QgY29tcGFyZSBjbGllbnREYXRhSlNPTiBhZ2FpbnN0IGEgdGVt
      cGxhdGUuIFNlZSBodHRwczovL2dvby5nbC95YWJQZXgiLCJvcmlnaW4iOiJodHRwOi8vbG9jYW
      xob3N0OjMwMDAiLCJ0eXBlIjoid2ViYXV0aG4uZ2V0In0=
    HEREDOC
  end

  def credential_id
    webauthn_id
  end

  def authenticator_data
    'SZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2MBAAAAcQ=='
  end

  def signature
    <<~HEREDOC
      MEYCIQC7VHQpZasv8URBC/VYKWcuv4MrmV82UfsESKTGgV3r+QIhAO8iAduYC7XDHJjpKkrSKb
      B3/YJKhlr2AA5uw59+aFzk
    HEREDOC
  end

  def platform_authenticator?
    Rack::Utils.parse_nested_query(URI(current_url).query)['platform'] == 'true'
  end
end
