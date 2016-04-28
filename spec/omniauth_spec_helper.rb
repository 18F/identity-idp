module OmniAuthSpecHelper
  def self.valid_saml_login_setup(email_address, uuid)
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :saml,
      provider: 'saml',
      uid: uuid,
      info: {
        email: email_address,
        uuid: uuid
      },
      extra: {
        raw_info: {
          email: email_address,
          uuid: uuid
        }
      }
    )
  end

  def self.invalid_credentials
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:saml] = :invalid_credentials
  end

  def self.invalid_ticket
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:saml] = :invalid_ticket
  end

  # http://stackoverflow.com/questions/19483367
  def self.silence_omniauth
    previous_logger = OmniAuth.config.logger
    OmniAuth.config.logger = Logger.new('/dev/null')
    yield
  ensure
    OmniAuth.config.logger = previous_logger
  end
end
