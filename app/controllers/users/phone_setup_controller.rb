module Users
  class PhoneSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation
    include Authorizable
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :authorize_user
    before_action :confirm_user_authenticated_for_2fa_setup

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

      result.success? ? handle_create_success(@user_phone_form.phone) : (render :index)
    end

    private

    def handle_create_success(phone)
      if MfaContext.new(current_user).phone_configurations.map(&:phone).index(phone).nil?
        prompt_to_confirm_phone(id: nil, phone: @user_phone_form.phone)
      else
        flash[:error] = t('errors.messages.phone_duplicate')
        redirect_to phone_setup_url
      end
    end

    def delivery_preference
      MfaContext.new(current_user).phone_configurations.take&.delivery_preference ||
        current_user.otp_delivery_preference
    end

    def user_phone_form_params
      params.require(:user_phone_form).permit(
        :international_code,
        :phone,
      )
    end
  end
end
