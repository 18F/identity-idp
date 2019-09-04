module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern

    before_action :find_user_with_confirmation_token
    before_action :confirm_user_needs_sign_up_confirmation
    before_action :stop_if_invalid_token

    def create
      process_confirmation
    rescue ActiveRecord::RecordNotUnique
      process_already_confirmed_user
    end

    private

    def process_successful_confirmation
      process_valid_confirmation_token
      request_id = params.fetch(:_request_id, '')
      Funnel::Registration::ConfirmEmail.call(@user.id)
      redirect_to sign_up_enter_password_url(
        request_id: request_id, confirmation_token: @confirmation_token,
      )
    end
  end
end
