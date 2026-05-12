# frozen_string_literal: true

# relies on `%w[user_session current_sp current_user]` being available to the controller.
module Idv
  module HistoricalAttemptsConcern
    extend ActiveSupport::Concern

    def cache_user_proofing_events(password)
      return unless historical_events_need_be_sent?

      existing_events = current_user
        .active_profile
        .decrypt_user_proofing_events(password:)

      kms_encrypted_events = SessionEncryptor.new.kms_encrypt(existing_events)
      user_session[:encrypted_proofing_events] = kms_encrypted_events
    end

    private

    def ial2_requested?
      resolved_authn_context_result.identity_proofing_or_ialmax? && current_user.identity_verified?
    end

    def historical_events_need_be_sent?
      return false unless historical_events_enabled?
      return false unless current_sp&.attempts_api_enabled?
      return false if existing_user_proofing_event.blank?

      return !existing_user_proofing_event.already_sent_to_sp?(current_sp.id)
    end

    def historical_events_enabled?
      return false unless IdentityConfig.store.historical_attempts_api_enabled

      ial2_requested?
    end

    def existing_user_proofing_event
      @existing_user_proofing_event ||= current_user.active_profile.user_proofing_event
    end

    def user_uuid
      @user_uuid ||= current_user['uuid']
    end
  end
end
