# frozen_string_literal: true

module Idv
  class  ReproofRequiredPolicy
    attr_reader :active_profile, :service_provider

    def initialize(active_profile:, service_provider:)
      @active_profile
      @service_provider = service_provider
    end

    def needs_to_reproof?
      reproof_forcing_sp? || caia_ipp_reproof_required?
    end

    private

    def initiating_service_provider
      active_profile&.initiating_service_provider
    end

    def reproof_forcing_sp?
      return false unless service_provider&.issuer == IdentityConfig.store.reproof_forcing_service_provider

      initiating_service_provider&.issuer != IdentityConfig.store.reproof_forcing_service_provider
    end

    def caia_ipp_reproof_required?
      return false unless IdentityConfig.store.caia_ipp_reproof_enabled
      return false unless service_provider&.issuer == IdentityConfig.store.caia_service_provider_issuer
      return false if active_profile.blank?

      ipp_proofed_profile?
    end

    def ipp_proofed_profile?
      Profile::IPP_PROOFING_IDV_LEVELS.include?(active_profile.idv_level)
    end
  end
end