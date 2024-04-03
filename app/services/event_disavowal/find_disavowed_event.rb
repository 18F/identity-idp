# frozen_string_literal: true

module EventDisavowal
  class FindDisavowedEvent
    attr_reader :disavowal_token

    def initialize(disavowal_token)
      @disavowal_token = disavowal_token
    end

    def call
      event
    end

    private

    def event
      # Use `#all` here instead of `#first` to avoid setting a 'LIMIT 1' to the
      # postgres query which causes it to run slowly.
      @event ||= Event.where(
        disavowal_token_fingerprint: disavowal_token_fingerprints,
      ).all[0]
    end

    def disavowal_token_fingerprints
      old_keys = IdentityConfig.store.hmac_fingerprinter_key_queue
      previous_key_fingerprints = old_keys.map do |key|
        Pii::Fingerprinter.fingerprint(disavowal_token, key)
      end
      [Pii::Fingerprinter.fingerprint(disavowal_token)] + previous_key_fingerprints
    end
  end
end
