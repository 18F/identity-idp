require 'openssl'

class Fingerprinter
  def self.fingerprint_cert(cert_pem)
    return nil unless cert_pem
    cert = OpenSSL::X509::Certificate.new(cert_pem)
    OpenSSL::Digest::SHA256.new(cert.to_der).hexdigest
  end
end
