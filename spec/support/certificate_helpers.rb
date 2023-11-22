require 'openssl'

module CertificateHelpers
  def custom_idp_x509_cert
    File.read('spec/support/certificates/custom_idp_cert.crt')
  end

  def custom_idp_secret_key
    File.read('spec/support/certificates/custom_idp_private_key.pem')
  end

  def custom_idp_x509_cert_fingerprint
    cert = OpenSSL::X509::Certificate.new(custom_idp_x509_cert)
    digest = OpenSSL::Digest::SHA1.new(cert.to_der)
    digest.hexdigest.upcase.scan(/.{2}/).join(':')
  end

  def cloudhsm_idp_x509_cert
    File.read('spec/support/certificates/cloudhsm_idp_cert.crt')
  end

  def cloudhsm_idp_secret_key
    File.read('spec/support/certificates/cloudhsm_idp_secret_key.pem')
  end

  def cloudhsm_idp_x509_cert_fingerprint
    cert = OpenSSL::X509::Certificate.new(cloudhsm_idp_x509_cert)
    digest = OpenSSL::Digest::SHA1.new(cert.to_der)
    digest.hexdigest.upcase.scan(/.{2}/).join(':')
  end

  def encrypted_secret_key
    key = OpenSSL::PKey::RSA.new(SamlIdp::Default::SECRET_KEY)
    key.to_pem(OpenSSL::Cipher::AES.new('128-CBC'), encrypted_secret_key_password)
  end

  def encrypted_secret_key_password
    'im a secret password.'
  end

  def invalid_cert
    OpenSSL::X509::Certificate.new(File.read('spec/support/certificates/too_short_cert.crt'))
  end
end
