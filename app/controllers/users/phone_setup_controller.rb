module Users
  class PhoneSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation
    include Authorizable

    before_action :authenticate_user
    before_action :authorize_user
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def index
      @user_phone_form = UserPhoneForm.new(current_user, nil)
      @presenter = PhoneSetupPresenter.new(delivery_preference)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
    end

    def create
      @user_phone_form = UserPhoneForm.new(current_user, nil)
      @presenter = PhoneSetupPresenter.new(delivery_preference)
      result = @user_phone_form.submit(user_phone_form_params)
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result.to_h)

      if result.success?
        prompt_to_confirm_phone(phone: @user_phone_form.phone)
      else
        render :index
      end
    end

    private

    def delivery_preference
      current_user.mfa.phone_configurations.first&.delivery_preference ||
        current_user.otp_delivery_preference
    end

    def two_factor_enabled?
      current_user.mfa.two_factor_enabled?
    end

    def user_phone_form_params
      params.require(:user_phone_form).permit(
        :international_code,
        :phone
      )
    end
  end
end
