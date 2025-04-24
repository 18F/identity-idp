# frozen_string_literal: true

module Idv
  class DuplicateSsnFinder
    attr_reader :ssn, :user

    def initialize(user:, ssn:)
      @user = user
      @ssn = ssn
    end

    def ssn_is_unique?
      Profile.where(ssn_signature: ssn_signatures).where.not(user_id: user.id).empty?
    end

    def associated_facial_match_profiles_with_ssn
      Profile.active.facial_match.where(ssn_signature: ssn_signatures).where.not(user_id: user.id)
    end

    def ial2_profile_ssn_is_unique?
      associated_facial_match_profiles_with_ssn.empty?
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
