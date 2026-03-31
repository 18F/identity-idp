# frozen_string_literal: true

module Idv
  class ReproofRequiredPolicy
    attr_reader :active_profile, :service_provider

    def initialize(active_profile:, service_provider:)
      @active_profile = active_profile
      @service_provider = service_provider
    end

    def needs_to_reproof?
      return false unless active_profile.present?
      reproof_forcing_sp? || non_facial_match_reproofing_required?
    end

    private

    def initiating_service_provider
      active_profile.initiating_service_provider
    end

    def reproof_forcing_sp?
      current_sp_is_reproof_forcing? && initiating_sp_isnt_reproof_forcing?
    end

    def non_facial_match_reproofing_required?
      return false unless eligible_sp_for_non_facial_match_reproofing?
      return false if active_profile.blank?

      !Profile::FACIAL_MATCH_OPT_IN.include?(active_profile.idv_level)
    end

    def eligible_sp_for_non_facial_match_reproofing?
      IdentityConfig.store.reproof_non_facial_match_service_providers
        .include?(service_provider.issuer)
    end

    def current_sp_is_reproof_forcing?
      service_provider.issuer == IdentityConfig.store.reproof_forcing_service_provider
    end

    def initiating_sp_isnt_reproof_forcing?
      active_profile.initiating_service_provider_issuer !=
        IdentityConfig.store.reproof_forcing_service_provider
    end
  end
end
