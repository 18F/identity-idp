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

      AttemptsApi::Cacher.new(current_user, user_session).save(password:, profile:)
    end

    def send_historic_events?
      return false, :idv_not_requested unless idv_requested?

      AttemptsApi::HistoricalReleaseCheck.new(profile:, sp: current_sp).call
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
