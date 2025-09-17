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

    def duplicate_facial_match_profiles(service_provider:)
      (Profile
        .active
        .facial_match
        .where(ssn_signature: ssn_signatures)
        .joins('INNER JOIN identities ON identities.user_id = profiles.user_id')
        .where(identities: { service_provider: service_provider })
        .where(identities: { deleted_at: nil })
        .where.not(user_id: user.id)
       + Profile
        .active
        .facial_match
        .where.not(user_id: user.id)
        .where(
          ssn_signature: ssn_signatures,
          initiating_service_provider_issuer: service_provider,
        )).distinct
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
