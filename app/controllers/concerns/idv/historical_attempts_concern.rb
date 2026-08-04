# frozen_string_literal: true

# relies on `%w[user_session current_sp current_user]` being available to the controller.
module Idv
  module HistoricalAttemptsConcern
    extend ActiveSupport::Concern

    def cache_user_proofing_events(password:)
      # we always need to cache events if the feature is enabled
      # in case we have to re-encrypt them
      return unless IdentityConfig.store.historical_attempts_api_enabled
      return unless profile.present?

      AttemptsApi::Cacher.new(current_user, user_session).save(password:)
    end

    def send_historic_events?
      return false, :idv_not_requested unless idv_requested?
      return false, :no_active_profile if profile.blank?
      return false, :no_user_proofing_event if existing_user_proofing_event.blank?
      return false, :already_sent if existing_user_proofing_event.already_sent_to_sp?(current_sp.id)
      return false, :no_encryped_file_reference if profile.encrypted_attempts_file_reference.blank?

      return true, nil
    end

    private

    def idv_requested?
      resolved_authn_context_result.identity_proofing_or_ialmax? && current_user.identity_verified?
    end

    def historical_events_enabled?
      IdentityConfig.store.historical_attempts_api_enabled
    end

    def profile
      @profile ||= current_user.active_profile
    end

    def existing_user_proofing_event
      @existing_user_proofing_event ||= profile.user_proofing_event
    end
  end
end
