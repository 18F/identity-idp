module Idv
  class PhoneErrorsController < ApplicationController
    include StepIndicatorConcern
    include IdvSession
    include Idv::AbTestAnalyticsConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_phone_step_needed
    before_action :confirm_idv_phone_step_submitted, except: [:failure]
    before_action :set_gpo_letter_available
    before_action :ignore_form_step_wait_requests

    def warning
      @remaining_attempts = rate_limiter.remaining_count

      if idv_session.previous_phone_step_params
        @phone = idv_session.previous_phone_step_params[:phone]
        @country_code = idv_session.previous_phone_step_params[:international_code]
      end

      track_event(type: :warning)
    end

    def timeout
      @remaining_step_attempts = rate_limiter.remaining_count
      track_event(type: :timeout)
    end

    def jobfail
      @remaining_attempts = rate_limiter.remaining_count
      track_event(type: :jobfail)
    end

    def failure
      return redirect_to(idv_phone_url) unless rate_limiter.limited?

      @expires_at = rate_limiter.expires_at
      track_event(type: :failure)
    end

    private

    def rate_limiter
      RateLimiter.new(user: idv_session.current_user, rate_limit_type: :proof_address)
    end

    def confirm_idv_phone_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_enter_password_url if idv_session.user_phone_confirmation == true
    end

    def confirm_idv_phone_step_submitted
      redirect_to idv_phone_url if idv_session.previous_phone_step_params.nil?
    end

    def ignore_form_step_wait_requests
      head(:no_content) if request.headers['HTTP_X_FORM_STEPS_WAIT']
    end

    def track_event(type:)
      attributes = { type: type }.merge(ab_test_analytics_buckets)
      if type == :failure
        attributes[:limiter_expires_at] = @expires_at
      else
        attributes[:remaining_attempts] = @remaining_attempts
      end

      analytics.idv_phone_error_visited(**attributes)
    end

    # rubocop:disable Naming/MemoizedInstanceVariableName
    def set_gpo_letter_available
      return @gpo_letter_available if defined?(@gpo_letter_available)
      @gpo_letter_available ||= FeatureManagement.gpo_verification_enabled? &&
                                !Idv::GpoMail.new(current_user).rate_limited?
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end
end
