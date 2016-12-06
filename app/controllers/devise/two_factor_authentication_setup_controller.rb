module Devise
  class TwoFactorAuthenticationSetupController < DeviseController
    include PhoneConfirmation
    include ScopeAuthenticator

    prepend_before_action :authenticate_scope!
    before_action :authorize_otp_setup

    # GET /users/otp
    def index
      @two_factor_setup_form = TwoFactorSetupForm.new(resource)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
    end

    # PATCH /users/otp
    def set
      @two_factor_setup_form = TwoFactorSetupForm.new(resource)

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
      elsif resource.two_factor_enabled?
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
