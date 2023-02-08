module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession
    include EffectiveUser

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed
    before_action :set_try_again_path, only: [:warning, :exception]

    def exception
      log_event
    end

    def warning
      throttle = Throttle.new(
        user: effective_user,
        throttle_type: :idv_resolution,
      )

      @remaining_attempts = throttle.remaining_count
      log_event based_on_throttle: throttle
    end

    def failure
      throttle = Throttle.new(
        user: effective_user,
        throttle_type: :idv_resolution,
      )
      @expires_at = throttle.expires_at
      log_event based_on_throttle: throttle
    end

    def ssn_failure
      throttle = nil

      if ssn_from_doc
        throttle = Throttle.new(
          target: Pii::Fingerprinter.fingerprint(ssn_from_doc),
          throttle_type: :proof_ssn,
        )
        @expires_at = throttle.expires_at
      end

      log_event based_on_throttle: throttle
      render 'idv/session_errors/failure'
    end

    def throttled
      throttle = Throttle.new(user: effective_user, throttle_type: :idv_doc_auth)
      log_event based_on_throttle: throttle
      @expires_at = throttle.expires_at
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

    def set_try_again_path
      if in_person_flow?
        @try_again_path = idv_in_person_path
      else
        @try_again_path = doc_auth_try_again_path
      end
    end

    def doc_auth_try_again_path
      if IdentityConfig.store.doc_auth_verify_info_controller_enabled
        idv_verify_info_url
      else
        idv_doc_auth_path
      end
    end

    def in_person_flow?
      params[:flow] == 'in_person'
    end

    def log_event(based_on_throttle: nil)
      options = {
        action: params[:action],
      }

      options[:attempts_remaining] = based_on_throttle.remaining_count if based_on_throttle

      @analytics.idv_session_errors_visited(**options)
    end
  end
end
