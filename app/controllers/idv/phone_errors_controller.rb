module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
    before_action :confirmat_phone_confirmation_needed

    def warning
      @remaining_step_attempts = remaining_step_attempts
    end

    def timeout
      @remaining_step_attempts = remaining_step_attempts
    end

    def jobfail
      @remaining_step_attempts = remaining_step_attempts
    end

    def failure; end

    private

    def confirmat_phone_confirmation_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        redirect_to idv_otp_delivery_method_url
      else
        redirect_to idv_review_url
      end
    end

    def phone_confirmation_required?
      idv_session.user_phone_confirmation != true
    end

    def remaining_step_attempts
      max_attempts = Throttle::THROTTLE_CONFIG[:idv_resolution][:max_attempts]
      attempt_count = idv_session.step_attempts[:phone]
      max_attempts - attempt_count
    end
  end
end
