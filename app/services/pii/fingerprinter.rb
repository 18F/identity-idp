module Pii
  class Fingerprinter
    def self.fingerprint(text)
      digest = OpenSSL::Digest::SHA256.new
      key = Figaro.env.hmac_fingerprinter_key
      OpenSSL::HMAC.hexdigest(digest, key, text)
    end
  end
end
