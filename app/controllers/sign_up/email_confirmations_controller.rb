module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern

    def create
      validate_token
    end

    private

    def process_successful_confirmation
      if !@user.confirmed?
        process_valid_confirmation_token
        request_id = params.fetch(:_request_id, '')
        redirect_to sign_up_enter_password_url(
          request_id: request_id, confirmation_token: @confirmation_token
        )
      else
        process_confirmed_user
      end
    end
  end
end
