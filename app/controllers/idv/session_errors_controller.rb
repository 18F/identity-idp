# frozen_string_literal: true

module Idv
  class SessionErrorsController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSessionConcern
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed
    before_action :set_resolution_rate_limiter, only: [:warning, :address_warning, :failure]
    before_action :set_try_again_path, only: [:warning, :exception, :state_id_warning]
    before_action :ignore_form_step_wait_requests

    attr_reader :resolution_rate_limiter

    def exception
      log_event
    end

    def warning
      @step_indicator_steps = step_indicator_steps
      @remaining_submit_attempts = resolution_rate_limiter.remaining_count
      log_event(based_on_limiter: resolution_rate_limiter)
    end

    def state_id_warning
      log_event
    end

    def address_warning
      @step_indicator_steps = step_indicator_steps
      @address_path = idv_address_url
      @remaining_submit_attempts = resolution_rate_limiter.remaining_count
      log_event(based_on_limiter: resolution_rate_limiter)
    end

    def failure
      @expires_at = resolution_rate_limiter.expires_at
      @sp_name = decorated_sp_session.sp_name
      log_event(based_on_limiter: resolution_rate_limiter)
    end

    def ssn_failure
      rate_limiter = nil

      if idv_session&.ssn
        rate_limiter = RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(idv_session.ssn),
          rate_limit_type: :proof_ssn,
        )
        @expires_at = rate_limiter.expires_at
      end

      log_event(based_on_limiter: rate_limiter)
      render 'idv/session_errors/failure'
    end

    def rate_limited
      rate_limiter = RateLimiter.new(user: idv_session_user, rate_limit_type: :idv_doc_auth)
      log_event(based_on_limiter: rate_limiter)
      @expires_at = rate_limiter.expires_at
    end

    private

    def set_resolution_rate_limiter
      @resolution_rate_limiter = RateLimiter.new(
        user: idv_session_user,
        rate_limit_type: :idv_resolution,
      )
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

    def log_event(based_on_limiter: nil)
      options = {
        type: params[:action],
      }

      options[:remaining_submit_attempts] = based_on_limiter.remaining_count if based_on_limiter

      analytics.idv_session_error_visited(**options)
    end
  end
end
