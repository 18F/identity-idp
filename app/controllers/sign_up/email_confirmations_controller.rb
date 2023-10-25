# frozen_string_literal: true

module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern
    include AuthorizationCountConcern

    before_action :find_user_with_confirmation_token
    before_action :confirm_user_needs_sign_up_confirmation
    before_action :stop_if_invalid_token
    before_action :store_sp_metadata_in_session, only: [:create]

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
      redirect_to sign_up_enter_password_url(confirmation_token: @confirmation_token)
    end

    def store_sp_metadata_in_session
      return if request_id.blank?
      StoreSpMetadataInSession.new(session:, request_id:).call
      bump_auth_count
    end

    def request_id
      params[:_request_id]
    end
  end
end
