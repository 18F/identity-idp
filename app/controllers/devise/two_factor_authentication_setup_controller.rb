module Devise
  class TwoFactorAuthenticationSetupController < DeviseController
    include ScopeAuthenticator

    before_action :authenticate_scope!
    before_action :authorize_otp_setup

    # GET /users/otp
    def index
    end

    # PATCH /users/otp
    def set
      process_valid_selections
    end

    private

    def authorize_otp_setup
      if user_fully_authenticated?
        redirect_to(request.referrer || root_url)
      elsif resource.two_factor_enabled?
        flash[:error] = t('devise.errors.messages.user_not_authenticated')
        redirect_to user_two_factor_authentication_path
      end
    end

    def otp_params
      params.require(:user).permit(:mobile)
    end

    def process_valid_selections
      resource.require_mobile_validation
      if resource.update(otp_params)
        update_metrics

        resource.send_two_factor_authentication_code

        flash[:success] = t('devise.two_factor_authentication.please_confirm')
        respond_with resource, location: user_two_factor_authentication_path
      else
        process_invalid_user
      end
    end

    def update_metrics
      ::NewRelic::Agent.increment_metric('Custom/User/OtpDeliverySetup')
    end

    def process_invalid_user
      updater = UserProfileUpdater.new(resource, flash)

      if updater.attribute_already_taken?
        updater.send_notifications

        flash[:success] = t('devise.two_factor_authentication.please_confirm')
        redirect_to user_two_factor_authentication_path
      else
        render :index, resource: resource
      end
    end
  end
end
