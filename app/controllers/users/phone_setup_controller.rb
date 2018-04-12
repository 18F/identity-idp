module Users
  class PhoneSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation

    before_action :authenticate_user
    before_action :authorize_phone_setup

    def index
      @user_phone_form = UserPhoneForm.new(current_user)
      @presenter = PhoneSetupPresenter.new(current_user.otp_delivery_preference)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
    end

    def create
      @user_phone_form = UserPhoneForm.new(current_user)
      @presenter = PhoneSetupPresenter.new(current_user.otp_delivery_preference)
      result = @user_phone_form.submit(user_phone_form_params)
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result.to_h)

      if result.success?
        prompt_to_confirm_phone(phone: @user_phone_form.phone)
      else
        render :index
      end
    end

    private

    def authorize_phone_setup
      if user_fully_authenticated?
        redirect_to account_url
      elsif current_user.two_factor_enabled?
        redirect_to user_two_factor_authentication_url
      end
    end

    def user_phone_form_params
      params.require(:user_phone_form).permit(
        :international_code,
        :phone
      )
    end
  end
end
