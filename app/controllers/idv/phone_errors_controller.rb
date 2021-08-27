module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_phone_step_needed

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

    def remaining_step_attempts
      Throttle.for(user: idv_session.current_user, throttle_type: :idv_resolution).remaining_count
    end

    def confirm_idv_phone_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_review_url if idv_session.user_phone_confirmation == true
    end
  end
end
