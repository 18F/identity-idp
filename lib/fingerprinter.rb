class Fingerprinter
  def self.fingerprint_cert(ssl_cert)
    return nil unless ssl_cert
    OpenSSL::Digest::SHA256.new(ssl_cert.to_der).hexdigest
  end
end
