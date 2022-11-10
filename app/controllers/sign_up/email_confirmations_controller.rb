module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern

    before_action :find_user_with_confirmation_token
    before_action :confirm_user_needs_sign_up_confirmation
    before_action :stop_if_invalid_token

    def create
      clear_setup_piv_cac_from_sign_in
      process_successful_confirmation
    rescue ActiveRecord::RecordNotUnique
      process_already_confirmed_user
    end

    private

    def clear_setup_piv_cac_from_sign_in
      session.delete(:needs_to_setup_piv_cac_after_sign_in)
    end

    def process_successful_confirmation
      process_valid_confirmation_token
      irs_attempts_api_tracker.user_registration_email_confirmation(
        email: @email_address&.email,
        success: true,
        failure_reason: nil,
      )
      request_id = params.fetch(:_request_id, '')
      redirect_to sign_up_enter_password_url(
        request_id: request_id, confirmation_token: @confirmation_token,
      )
    end
  end
end
