require 'openssl'

module AamvaFixtures
  def self.example_config
    Proofing::Aamva::Proofer::Config.new(
      cert_enabled: 'false',
      private_key: Base64.strict_encode64(aamva_private_key.to_der),
      public_key: Base64.strict_encode64(aamva_public_key.to_der),
      verification_url: 'https://verificationservices-primary.example.com:18449/dldv/2.1/valuefree',
      auth_url: 'https://authentication-cert.example.com/Authentication/Authenticate.svc',
    )
  end

  def self.aamva_private_key
    @aamva_private_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def self.aamva_public_key
    @aamva_public_key ||= begin
      current_time = Time.zone.now
      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/C=BE/O=Test/OU=Test/CN=Test')
      cert.not_before = current_time
      cert.not_after = current_time + 365 * 24 * 60 * 60
      cert.public_key = aamva_private_key.public_key
      cert.serial = 0x0
      cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.extensions = [
        ef.create_extension('basicConstraints', 'CA:TRUE', true),
        ef.create_extension('subjectKeyIdentifier', 'hash'),
      ]
      cert.add_extension ef.create_extension(
        'authorityKeyIdentifier',
        'keyid:always,issuer:always',
      )

      cert.sign aamva_private_key, OpenSSL::Digest.new('SHA256')
      cert
    end
  end

  def self.aamva_test_data
    read_fixture_file('aamva_test_data.csv')
  end

  def self.authentication_token_request
    read_fixture_file('proofing/aamva/requests/authentication_token_request.xml')
      .gsub(/^\s+/, '')
      .gsub(/\s+$/, '')
      .delete("\n") + "\n"
  end

  def self.authentication_token_response
    read_fixture_file('proofing/aamva/responses/authentication_token_response.xml')
  end

  def self.security_token_request
    read_fixture_file('proofing/aamva/requests/security_token_request.xml')
      .gsub(/^\s+/, '')
      .gsub(/\s+$/, '')
      .delete("\n") + "\n"
  end

  def self.security_token_response
    read_fixture_file('proofing/aamva/responses/security_token_response.xml')
  end

  def self.soap_fault_response
    read_fixture_file('proofing/aamva/responses/soap_fault_response.xml')
  end

  def self.soap_fault_response_simplified
    XmlHelper.delete_xml_at_xpath(
      soap_fault_response,
      '//ProgramExceptions',
    )
  end

  def self.verification_request
    read_fixture_file('proofing/aamva/requests/verification_request.xml')
  end

  def self.verification_response_with_newline_in_transaction_id
    read_fixture_file(
      'proofing/aamva/responses/verification_response_with_newline_in_transaction_id.xml',
    )
  end

  def self.verification_response
    read_fixture_file('proofing/aamva/responses/verification_response.xml')
  end

  def self.verification_response_namespaced_success
    read_fixture_file('proofing/aamva/responses/verification_response_namespaced_success.xml')
  end

  def self.verification_response_namespaced_failure
    read_fixture_file('proofing/aamva/responses/verification_response_namespaced_failure.xml')
  end

  private_class_method def self.read_fixture_file(path)
    fullpath = File.join(
      File.dirname(__FILE__),
      '../fixtures',
      path,
    )
    File.read(fullpath)
  end
end
