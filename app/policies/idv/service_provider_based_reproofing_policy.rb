# frozen_string_literal: true

module Idv
  class ServiceProviderBasedReproofingPolicy
    attr_reader :active_profile, :resolved_authn_context_result, :service_provider

    def initialize(active_profile:, service_provider:, resolved_authn_context_result:)
      @active_profile = active_profile
      @service_provider = service_provider
      @resolved_authn_context_result = resolved_authn_context_result
    end

    def needs_to_reproof?
      return false unless active_profile.present?
      return false unless service_provider.present?
      return false unless resolved_authn_context_result&.facial_match?
      reproof_forcing_sp? || unsupervised_with_selfie_reproofing_required?
    end

    private

    def initiating_service_provider
      active_profile.initiating_service_provider
    end

    def reproof_forcing_sp?
      current_sp_is_reproof_forcing? && current_sp_is_not_initiating_sp?
    end

    def current_sp_is_reproof_forcing?
      service_provider.issuer == IdentityConfig.store.reproof_forcing_service_provider
    end

    def unsupervised_with_selfie_reproofing_required?
      return false unless eligible_sp_for_unsupervised_with_selfie_reproofing?
      return false if active_profile.blank?

      !Profile::FACIAL_MATCH_OPT_IN.include?(active_profile.idv_level)
    end

    def eligible_sp_for_unsupervised_with_selfie_reproofing?
      IdentityConfig.store.reproof_if_not_unsupervised_with_selfie_service_providers
        .include?(service_provider.issuer)
    end

    def current_sp_is_not_initiating_sp?
      service_provider.issuer != active_profile.initiating_service_provider_issuer
    end

    def initiating_sp_isnt_reproof_forcing?
      active_profile.initiating_service_provider_issuer !=
        IdentityConfig.store.reproof_forcing_service_provider
    end
  end
end
