module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation

    before_action :authorize_otp_setup
    before_action :authenticate_user
    skip_before_action :handle_two_factor_authentication

    def index
      @user_phone_form = UserPhoneForm.new(current_user)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
    end

    def set
      @user_phone_form = UserPhoneForm.new(current_user)
      result = @user_phone_form.submit(params[:user_phone_form])

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result.to_h)

      if result.success?
        process_valid_form
      else
        render :index
      end
    end

    private

    def authorize_otp_setup
      if user_fully_authenticated?
        redirect_to(request.referer || root_url)
      elsif current_user && current_user.two_factor_enabled?
        redirect_to user_two_factor_authentication_url
      end
    end

    def process_valid_form
      prompt_to_confirm_phone(phone: @user_phone_form.phone)
    end
  end
end
