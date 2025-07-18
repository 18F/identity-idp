# frozen_string_literal: true

module Idv
  class DuplicateSsnFinder
    attr_reader :ssn, :user, :issuer

    def initialize(user:, ssn:, issuer:)
      @user = user
      @ssn = ssn
      @issuer = issuer
    end

    def ssn_is_unique?
      Profile.where(ssn_signature: ssn_signatures).where.not(user_id: user.id).empty?
    end

    def associated_facial_match_profiles_with_ssn
      Profile.joins(:sp_return_logs)
        .active
        .facial_match
        .where(ssn_signature: ssn_signatures)
        .where(sp_return_logs: { issuer: sp_eligible_for_one_account })
        .where.not(user_id: user.id)
        .distinct
    end

    def ial2_profile_ssn_is_unique?
      associated_facial_match_profiles_with_ssn.empty?
    end

    # Due to potentially inconsistent normalization of stored SSNs in the past, we must check:
    # - No dashes, ex: 123456789
    # - Dashes, ex: 123-45-6789
    # - Only first dash, ex: 123-456789
    # - Only second dash, ex: 12345-6789
    #
    # The latter two cases are particularly unlikely, but are included for completeness' sake.
    def ssn_signatures
      formatted_ssn = SsnFormatter.format(ssn)
      normalized_ssn = SsnFormatter.normalize(ssn)
      only_first_dash_ssn = "#{normalized_ssn[0..2]}-#{normalized_ssn[3..8]}"
      only_second_dash_ssn = "#{normalized_ssn[0..4]}-#{normalized_ssn[5..8]}"

      ssns = [formatted_ssn, normalized_ssn, only_first_dash_ssn, only_second_dash_ssn]

      keys = [Pii::Fingerprinter.current_key] + IdentityConfig.store.hmac_fingerprinter_key_queue
      keys.flat_map do |key|
        ssns.map do |ssn|
          Pii::Fingerprinter.fingerprint(ssn, key)
        end
      end
    end

    def sp_eligible_for_one_account
      IdentityConfig.store.eligible_one_account_providers
    end
  end
end
