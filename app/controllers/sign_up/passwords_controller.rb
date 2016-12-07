module SignUp
  class PasswordsController < ApplicationController
    include UnconfirmedUserConcern

    def create
      with_unconfirmed_user do
        result = @password_form.submit(permitted_params)
        analytics.track_event(Analytics::PASSWORD_CREATION, result)

        if result[:success]
          process_successful_password_creation
        else
          process_unsuccessful_password_creation
        end
      end
    end

    private

    def permitted_params
      params.require(:password_form).permit(:confirmation_token, :password)
    end

    def process_successful_password_creation
      @user.confirm
      @user.update(reset_requested_at: nil, password: permitted_params[:password])
      sign_in_and_redirect_user
    end

    def process_unsuccessful_password_creation
      @confirmation_token = params[:confirmation_token]
      render 'sign_up/confirmations/show'
    end

    def sign_in_and_redirect_user
      sign_in @user
      redirect_to after_confirmation_path_for(@user)
    end
  end
end
