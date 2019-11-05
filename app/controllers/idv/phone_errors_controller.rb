module Idv
  class PhoneErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated_or_recovery
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
      max_attempts = Throttle::THROTTLE_CONFIG[:idv_resolution][:max_attempts]
      attempt_count = idv_session.step_attempts[:phone]
      max_attempts - attempt_count
    end

    def confirm_two_factor_authenticated_or_recovery
      return if session[:ial2_recovery_user_id].present?
      confirm_two_factor_authenticated
    end

    def confirm_idv_phone_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_review_url if idv_session.user_phone_confirmation == true
    end

    def user_id
      ial2_recovery_user_id = session[:ial2_recovery_user_id]
      return ial2_recovery_user_id if ial2_recovery_user_id.present?
      current_user.id
    end
  end
end
