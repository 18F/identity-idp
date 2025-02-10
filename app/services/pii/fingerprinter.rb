# frozen_string_literal: true

module Pii
  class Fingerprinter
    def self.current_key
      IdentityConfig.store.hmac_fingerprinter_key
    end

    def self.fingerprint(text, key = current_key)
      digest = OpenSSL::Digest.new('SHA256')
      OpenSSL::HMAC.hexdigest(digest, key, text)
    end

    def self.previous_fingerprints(text)
      IdentityConfig.store.hmac_fingerprinter_key_queue.map do |key|
        fingerprint(text, key)
      end
    end

    def self.verify(text, fingerprint)
      verify_current(text, fingerprint) || verify_queue(text, fingerprint)
    end

    def self.verify_current(text, fingerprint)
      ActiveSupport::SecurityUtils.secure_compare(fingerprint, fingerprint(text))
    end

    def self.verify_queue(text, fingerprint)
      IdentityConfig.store.hmac_fingerprinter_key_queue.each do |key|
        return true if ActiveSupport::SecurityUtils.secure_compare(
          fingerprint, fingerprint(text, key)
        )
      end
      false
    end

    def self.stale?(text, fingerprint)
      return true if text.present? && fingerprint.nil?
      !verify_current(text, fingerprint)
    end
  end
end
