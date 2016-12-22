module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation

    before_action :authorize_otp_setup
    before_action :authenticate_user
    skip_before_action :handle_two_factor_authentication

    def index
      @two_factor_setup_form = TwoFactorSetupForm.new(current_user)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
    end

    def set
      @two_factor_setup_form = TwoFactorSetupForm.new(current_user)
      result = @two_factor_setup_form.submit(params[:two_factor_setup_form])

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result)

      if result[:success]
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
        redirect_to user_two_factor_authentication_path
      end
    end

    def process_valid_form
      prompt_to_confirm_phone(
        phone: @two_factor_setup_form.phone,
        otp_method: @two_factor_setup_form.otp_method
      )
    end
  end
end
