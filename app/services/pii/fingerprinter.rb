module Pii
  class Fingerprinter
    def self.fingerprint(text)
      digest = OpenSSL::Digest::SHA256.new
      key = Figaro.env.hmac_fingerprinter_key
      OpenSSL::HMAC.hexdigest(digest, key, text)
    end

    def self.verify(text, fingerprint)
      ActiveSupport::SecurityUtils.secure_compare(fingerprint, fingerprint(text))
    end
  end
end
