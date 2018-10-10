module WebauthnHelper
  def mock_challenge
    allow(WebAuthn).to receive(:credential_creation_options).and_return(
      challenge: challenge.pack('c*')
    )
  end

  def fill_in_nickname_and_click_continue
    fill_in 'name', with: 'mykey'
  end

  def mock_submit_without_pressing_button_on_hardware_key
    first('#submit-button', visible: false).click
  end

  def mock_press_button_on_hardware_key
    # this is required because the domain is embedded in the supplied attestation object
    allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

    # simulate javascript that is triggered when the hardware key button is pressed

    set_hidden_field('attestation_object', attestation_object)
    set_hidden_field('client_data_json', client_data_json)

    first('#submit-button', visible: false).click
  end

  def set_hidden_field(id, value)
    first("input##{id}", visible: false).set(value)
  end

  def protocol
    'http://'
  end

  def attestation_object
    <<~HEREDOC
      o2NmbXRoZmlkby11MmZnYXR0U3RtdKJjc2lnWEcwRQIhALPWZKH5+O5MbcTX/si5CWbYExXTgRGmZ3BYDHEQ0zM2AiBLZ
      rHCEXeifub4u0QT2CsIzNF0JfZ42BjI7SLzd33FXGN4NWOBWQLCMIICvjCCAaagAwIBAgIEdIb9wjANBgkqhkiG9w0BAQ
      sFADAuMSwwKgYDVQQDEyNZdWJpY28gVTJGIFJvb3QgQ0EgU2VyaWFsIDQ1NzIwMDYzMTAgFw0xNDA4MDEwMDAwMDBaGA8
      yMDUwMDkwNDAwMDAwMFowbzELMAkGA1UEBhMCU0UxEjAQBgNVBAoMCVl1YmljbyBBQjEiMCAGA1UECwwZQXV0aGVudGlj
      YXRvciBBdHRlc3RhdGlvbjEoMCYGA1UEAwwfWXViaWNvIFUyRiBFRSBTZXJpYWwgMTk1NTAwMzg0MjBZMBMGByqGSM49A
      gEGCCqGSM49AwEHA0IABJVd8633JH0xde/9nMTzGk6HjrrhgQlWYVD7OIsuX2Unv1dAmqWBpQ0KxS8YRFwKE1SKE1PIpO
      WacE5SO8BN6+2jbDBqMCIGCSsGAQQBgsQKAgQVMS4zLjYuMS40LjEuNDE0ODIuMS4xMBMGCysGAQQBguUcAgEBBAQDAgU
      gMCEGCysGAQQBguUcAQEEBBIEEPigEfOMCk0VgAYXER+e3H0wDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEA
      MVxIgOaaUn44Zom9af0KqG9J655OhUVBVW+q0As6AIod3AH5bHb2aDYakeIyyBCnnGMHTJtuekbrHbXYXERIn4aKdkPSK
      lyGLsA/A+WEi+OAfXrNVfjhrh7iE6xzq0sg4/vVJoywe4eAJx0fS+Dl3axzTTpYl71Nc7p/NX6iCMmdik0pAuYJegBcTc
      kE3AoYEg4K99AM/JaaKIblsbFh8+3LxnemeNf7UwOczaGGvjS6UzGVI0Odf9lKcPIwYhuTxM5CaNMXTZQ7xq4/yTfC3kP
      WtE4hFT34UJJflZBiLrxG4OsYxkHw/n5vKgmpspB3GfYuYTWhkDKiE8CYtyg87mhhdXRoRGF0YVjESZYN5YgOjGh0NBcP
      ZHZgW4/krrmihjLHmVzzuoMdl2NBAAAAAAAAAAAAAAAAAAAAAAAAAAAAQKqDS1W7h4/KNbFPClTaqeglJdkHUe6OWQIZo
      5iJsTY+Aomll+hR+iMpbRxiKuuK3pYDcJ0dg3Gk2/zXB+4o+LalAQIDJiABIVggH/apoWRf+cr+ViGgqizMcQFz3WTsQA
      Q+bgj5ZDl+d1giWCA+Q7Uff+TEiSLXuT/OtsPil4gRy1ITS4tv8m6n1JLYlw==
    HEREDOC
  end

  def client_data_json
    <<~HEREDOC
      eyJjaGFsbGVuZ2UiOiJncjEycndSVVVIWnFvNkZFSV9ZbEFnIiwib3JpZ2luIjoiaHR0cDovL2xvY2FsaG9zdDozMDAwI
      iwidHlwZSI6IndlYmF1dGhuLmNyZWF0ZSJ9
    HEREDOC
  end

  def challenge
    [130, 189, 118, 175, 4, 84, 80, 118, 106, 163, 161, 68, 35, 246, 37, 2]
  end
end
