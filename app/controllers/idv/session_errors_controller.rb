module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed

    def warning
      @remaining_step_attempts = remaining_step_attempts
    end

    private

    def remaining_step_attempts
      Throttle.for(
        target: user_id,
        throttle_type: :idv_resolution,
      ).remaining_count
    end

    def confirm_two_factor_authenticated_or_user_id_in_session
      return if session[:doc_capture_user_id].present?

      confirm_two_factor_authenticated
    end

    def confirm_idv_session_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end

    def user_id
      doc_capture_user_id = session[:doc_capture_user_id]
      return doc_capture_user_id if doc_capture_user_id.present?

      current_user.id
    end
  end
end
