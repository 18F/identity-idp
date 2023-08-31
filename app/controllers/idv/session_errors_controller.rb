module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed
    before_action :set_try_again_path, only: [:warning, :exception, :state_id_warning]
    before_action :ignore_form_step_wait_requests

    def exception
      log_event
    end

    def warning
      throttle = Throttle.new(
        user: idv_session_user,
        throttle_type: :idv_resolution,
      )

      @remaining_attempts = throttle.remaining_count
      log_event(based_on_throttle: throttle)
    end

    def state_id_warning
      log_event
    end

    def failure
      throttle = Throttle.new(
        user: idv_session_user,
        throttle_type: :idv_resolution,
      )
      @expires_at = throttle.expires_at
      @sp_name = decorated_session.sp_name
      log_event(based_on_throttle: throttle)
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

      log_event(based_on_throttle: throttle)
      render 'idv/session_errors/failure'
    end

    def throttled
      throttle = Throttle.new(user: idv_session_user, throttle_type: :idv_doc_auth)
      log_event(based_on_throttle: throttle)
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
      redirect_to idv_phone_url if idv_session.verify_info_step_complete?
    end

    def ignore_form_step_wait_requests
      head(:no_content) if request.headers['HTTP_X_FORM_STEPS_WAIT']
    end

    def set_try_again_path
      if in_person_flow?
        @try_again_path = idv_in_person_verify_info_url
      else
        @try_again_path = idv_verify_info_url
      end
    end

    def in_person_flow?
      params[:flow] == 'in_person'
    end

    def log_event(based_on_throttle: nil)
      options = {
        type: params[:action],
      }

      options[:attempts_remaining] = based_on_throttle.remaining_count if based_on_throttle

      analytics.idv_session_error_visited(**options)
    end
  end
end
