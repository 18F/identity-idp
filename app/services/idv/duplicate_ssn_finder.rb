module Idv
  class DuplicateSsnFinder
    attr_reader :ssn, :user

    def initialize(user:, ssn:)
      @user = user
      @ssn = ssn
    end

    def ssn_is_unique?
      Profile.where.not(user_id: user.id).where(ssn_signature: ssn_signatures).empty?
    end

    private

    def ssn_signatures
      current_signature = ssn_signature(Pii::Fingerprinter.current_key)
      old_signatures = KeyRotator::Utils.old_keys(:hmac_fingerprinter_key_queue).map do |key|
        ssn_signature(key)
      end
      [current_signature] + old_signatures
    end

    def ssn_signature(key)
      Pii::Fingerprinter.fingerprint(ssn, key)
    end
  end
end
