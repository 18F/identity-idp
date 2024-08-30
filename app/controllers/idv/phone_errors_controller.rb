# frozen_string_literal: true

module Idv
  class PhoneErrorsController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include Idv::AbTestAnalyticsConcern
    include Idv::VerifyByMailConcern

    before_action :confirm_step_allowed, except: [:failure]
    before_action :set_gpo_letter_available
    before_action :ignore_form_step_wait_requests

    def warning
      @remaining_submit_attempts = rate_limiter.remaining_count

      if idv_session.previous_phone_step_params
        @phone = idv_session.previous_phone_step_params[:phone]
        @country_code = idv_session.previous_phone_step_params[:international_code]
      end

      track_event(type: :warning)
    end

    def timeout
      @remaining_submit_attempts = rate_limiter.remaining_count
      track_event(type: :timeout)
    end

    def jobfail
      @remaining_submit_attempts = rate_limiter.remaining_count
      track_event(type: :jobfail)
    end

    def failure
      return redirect_to(idv_phone_url) unless rate_limiter.limited?

      @expires_at = rate_limiter.expires_at
      track_event(type: :failure)
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :phone_errors,
        controller: self,
        action: :failure,
        next_steps: [FlowPolicy::FINAL],
        preconditions: ->(idv_session:, user:) { idv_session.previous_phone_step_params.present? },
        undo_step: ->(idv_session:, user:) {},
      )
    end

    private

    def rate_limiter
      RateLimiter.new(user: idv_session.current_user, rate_limit_type: :proof_address)
    end

    def ignore_form_step_wait_requests
      head(:no_content) if request.headers['HTTP_X_FORM_STEPS_WAIT']
    end

    def track_event(type:)
      attributes = { type: type }.merge(ab_test_analytics_buckets)
      if type == :failure
        attributes[:limiter_expires_at] = @expires_at
      else
        attributes[:remaining_submit_attempts] = @remaining_submit_attempts
      end

      analytics.idv_phone_error_visited(**attributes)
    end

    def set_gpo_letter_available
      @gpo_letter_available = gpo_verify_by_mail_policy.send_letter_available?
    end
  end
end
