module Pii
  class Fingerprinter
    def self.fingerprint(text, key = Figaro.env.hmac_fingerprinter_key)
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::HMAC.hexdigest(digest, key, text)
    end

    def self.verify(text, fingerprint)
      verify_current(text, fingerprint) || verify_queue(text, fingerprint)
    end

    def self.verify_current(text, fingerprint)
      ActiveSupport::SecurityUtils.secure_compare(fingerprint, fingerprint(text))
    end

    def self.verify_queue(text, fingerprint)
      KeyRotator::Utils.old_keys(:hmac_fingerprinter_key_queue).each do |key|
        return true if ActiveSupport::SecurityUtils.secure_compare(
          fingerprint, fingerprint(text, key)
        )
      end
      false
    end

    def self.stale?(text, fingerprint)
      !verify_current(text, fingerprint)
    end
  end
end
