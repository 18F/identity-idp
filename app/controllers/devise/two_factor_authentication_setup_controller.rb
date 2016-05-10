module Devise
  class TwoFactorAuthenticationSetupController < DeviseController
    include ScopeAuthenticator

    before_action :authenticate_scope!
    before_action :authorize_otp_setup

    # GET /users/otp
    def index
      @two_factor_setup_form = TwoFactorSetupForm.new(resource)
    end

    # PATCH /users/otp
    def set
      @two_factor_setup_form = TwoFactorSetupForm.new(resource)

      if @two_factor_setup_form.submit(params[:two_factor_setup_form])
        process_valid_form
      else
        process_invalid_form
      end
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

    def process_valid_form
      update_metrics

      resource.send_two_factor_authentication_code

      flash[:success] = t('devise.two_factor_authentication.please_confirm')
      respond_with resource, location: user_two_factor_authentication_path
    end

    def update_metrics
      ::NewRelic::Agent.increment_metric('Custom/User/OtpDeliverySetup')
    end

    def process_invalid_form
      updater = UserProfileUpdater.new(@two_factor_setup_form)

      if updater.attribute_already_taken?
        updater.send_notifications

        flash[:success] = t('devise.two_factor_authentication.please_confirm')
        redirect_to user_two_factor_authentication_path
      else
        render :index
      end
    end
  end
end
