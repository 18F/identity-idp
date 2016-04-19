module OmniAuthSpecHelper
  def self.valid_saml_login_setup(email_address, uuid, groups = 'PUBLIC-SG-UPAYA-Applicant')
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :saml,
      provider: 'saml',
      uid: uuid,
      info: {
        email: email_address,
        uuid: uuid,
        first_name: 'first name',
        last_name: 'last name',
        groups: groups
      },
      extra: {
        raw_info: {
          emailAddress: email_address,
          UUID: uuid,
          sn: 'first name',
          givenName: 'last name',
          groups: groups
        }
      }
    )
  end

  def self.invalid_saml_login_setup
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:saml] = :invalid_credentials
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
