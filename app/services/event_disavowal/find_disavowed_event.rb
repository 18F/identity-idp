module EventDisavowal
  class FindDisavowedEvent
    attr_reader :disavowal_token

    def initialize(disavowal_token)
      @disavowal_token = disavowal_token
    end

    def call
      @event ||= Event.where(
        disavowal_token_fingerprint: disavowal_token_fingerprints,
      ).first
    end

    private

    def disavowal_token_fingerprints
      old_keys = KeyRotator::Utils.old_keys(:hmac_fingerprinter_key_queue)
      previous_key_fingerprints = old_keys.map do |key|
        Pii::Fingerprinter.fingerprint(disavowal_token, key)
      end
      [Pii::Fingerprinter.fingerprint(disavowal_token)] + previous_key_fingerprints
    end
  end
end
