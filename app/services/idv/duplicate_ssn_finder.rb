# frozen_string_literal: true

module Idv
  class DuplicateSsnFinder
    attr_reader :ssn, :user

    def initialize(user:, ssn:)
      @user = user
      @ssn = ssn
    end

    def ssn_is_unique?
      associated_profiles_with_matching_ssn.empty?
    end

    def associated_profiles_with_matching_ssn
      Profile.where.not(user_id: user.id).where(ssn_signature: ssn_signatures)
    end

    private

    def ssn_signatures
      current_signature = ssn_signature(Pii::Fingerprinter.current_key)
      old_signatures = IdentityConfig.store.hmac_fingerprinter_key_queue.map do |key|
        ssn_signature(key)
      end
      [current_signature] + old_signatures
    end

    def ssn_signature(key)
      Pii::Fingerprinter.fingerprint(ssn, key)
    end
  end
end
