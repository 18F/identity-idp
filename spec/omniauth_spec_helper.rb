module OmniAuthSpecHelper
  def self.valid_saml_login_setup(email_address, uuid)
    config.test_mode = true
    config.add_mock(
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
    config.test_mode = true
    config.mock_auth[:saml] = :invalid_credentials
  end

  def self.invalid_ticket
    config.test_mode = true
    config.mock_auth[:saml] = :invalid_ticket
  end

  # http://stackoverflow.com/questions/19483367
  def self.silence_omniauth
    previous_logger = config.logger
    config.logger = Logger.new('/dev/null')
    yield
  ensure
    config.logger = previous_logger
  end

  def self.config
    @config ||= OmniAuth.config
  end
end
