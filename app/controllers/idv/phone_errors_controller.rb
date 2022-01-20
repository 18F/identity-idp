module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_phone_step_needed

    def warning
      @remaining_step_attempts = throttle.remaining_count
      track_event(type: :warning)
    end

    def jobfail
      @remaining_step_attempts = throttle.remaining_count
      track_event(type: :jobfail)
    end

    def failure
      @expires_at = throttle.expires_at
      track_event(type: :failure)
    end

    private

    def throttle
      Throttle.for(user: idv_session.current_user, throttle_type: :proof_address)
    end

    def confirm_idv_phone_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_review_url if idv_session.user_phone_confirmation == true
    end

    def track_event(type:)
      attributes = { type: type }
      if type == :failure
        attributes[:throttle_expires_at] = @expires_at
      else
        attributes[:remaining_step_attempts] = @remaining_step_attempts
      end

      analytics.track_event(Analytics::IDV_PHONE_ERROR_VISITED, attributes)
    end
  end
end
