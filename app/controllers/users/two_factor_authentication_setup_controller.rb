module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator

    before_action :authenticate_user
    before_action :authorize_2fa_setup

    def index
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP_VISIT)
    end

    def create
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      result = @two_factor_options_form.submit(two_factor_options_form_params)
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP, result.to_h)

      if result.success?
        process_valid_form
      else
        render :index
      end
    end

    private

    def authorize_2fa_setup
      if user_fully_authenticated?
        redirect_to account_url
      elsif current_user.two_factor_enabled?
        redirect_to user_two_factor_authentication_url
      end
    end

    def process_valid_form
      case @two_factor_options_form.selection
      when 'sms', 'voice'
        redirect_to phone_setup_url
      when 'auth_app'
        redirect_to authenticator_setup_url
      end
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection)
    end
  end
end
