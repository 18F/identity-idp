module WebAuthnHelper
  include JavascriptDriverHelper

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
    first('#submit-button', visible: false).click
  end

  def mock_press_button_on_hardware_key_on_setup
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    # simulate javascript that is triggered when the hardware key button is pressed
    set_hidden_field('webauthn_id', webauthn_id)
    set_hidden_field('webauthn_public_key', webauthn_public_key)
    set_hidden_field('attestation_object', attestation_object)
    set_hidden_field('client_data_json', setup_client_data_json)

    button = first('#submit-button', visible: false)
    if javascript_enabled?
      button.execute_script('this.click()')
    else
      button.click
    end
  end

  def mock_press_button_on_hardware_key_on_verification
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    # simulate javascript that is triggered when the hardware key button is pressed
    set_hidden_field('credential_id', credential_id)
    set_hidden_field('authenticator_data', authenticator_data)
    set_hidden_field('signature', signature)
    set_hidden_field('client_data_json', verification_client_data_json)
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
end
