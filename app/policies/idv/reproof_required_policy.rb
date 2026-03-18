# frozen_string_literal: true

module Idv
  class  ReproofRequiredPolicy
    attr_reader :active_profile, :service_provider

    def initialize(active_profile:, service_provider:)
      @active_profile = active_profile
      @service_provider = service_provider
    end

    def needs_to_reproof?
      reproof_forcing_sp? || ipp_reproofing_required?
    end

    private

    def initiating_service_provider
      active_profile&.initiating_service_provider
    end

    def reproof_forcing_sp?
      return false unless current_sp_is_reproof_forcing? && initiating_sp_isnt_reproof_forcing?
    end

    def ipp_reproofing_required?
      return false unless IdentityConfig.store.caia_ipp_reproof_enabled
      return false unless eligible_sp_for_reproofing?
      return false if active_profile.blank?

      active_profile.ipp_proofed?
    end

    def eligible_sp_for_reproofing?
        IdentityConfig.store.reproof_ipp_service_providers.include?(service_provider&.issuer)
    end

    def current_sp_is_reproof_forcing?
      service_provider&.issuer == IdentityConfig.store.reproof_forcing_service_provider
    end

    def initiating_sp_isnt_reproof_forcing?
      initiating_service_provider != IdentityConfig.store.reproof_forcing_service_provider
    end
  end
end