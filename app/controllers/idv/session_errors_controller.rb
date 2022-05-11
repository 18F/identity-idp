module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession
    include EffectiveUser

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed

    def warning
      @remaining_attempts = Throttle.new(
        user: effective_user,
        throttle_type: :idv_resolution,
      ).remaining_count
    end

    def failure
      @expires_at = Throttle.new(
        user: effective_user,
        throttle_type: :idv_resolution,
      ).expires_at
    end

    def ssn_failure
      if ssn_from_doc
        @expires_at = Throttle.new(
          target: Pii::Fingerprinter.fingerprint(ssn_from_doc),
          throttle_type: :proof_ssn,
        ).expires_at
      end

      render 'idv/session_errors/failure'
    end

    def throttled
      @expires_at = Throttle.new(user: effective_user, throttle_type: :idv_doc_auth).expires_at
    end

    private

    def ssn_from_doc
      user_session&.dig('idv/doc_auth', 'pii_from_doc', 'ssn')
    end

    def confirm_two_factor_authenticated_or_user_id_in_session
      return if session[:doc_capture_user_id].present?

      confirm_two_factor_authenticated
    end

    def confirm_idv_session_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end
  end
end
