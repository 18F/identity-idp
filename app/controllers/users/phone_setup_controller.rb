module Users
  class PhoneSetupController < ApplicationController
    include UserAuthenticator
    include PhoneConfirmation
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_setup_presenter

    def index
      @new_phone_form = NewPhoneForm.new(current_user)
      analytics.track_event(Analytics::USER_REGISTRATION_PHONE_SETUP_VISIT)
      # TODO: Refactor
      mfa_user = MfaContext.new(current_user)
      analytics.user_registration_2fa_method_setup_visit(
        method_name: 'phone',
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count
      )
    end

    def create
      @new_phone_form = NewPhoneForm.new(current_user)
      result = @new_phone_form.submit(new_phone_form_params)
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_PHONE_SETUP, result.to_h)

      if result.success?
        handle_create_success(@new_phone_form.phone)
      else
        render :index
      end
    end

    private

    def set_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def user_opted_remember_device_cookie
      cookies.encrypted[:user_opted_remember_device_preference]
    end

    def handle_create_success(phone)
      if MfaContext.new(current_user).phone_configurations.map(&:phone).index(phone).nil?
        prompt_to_confirm_phone(
          id: nil,
          phone: @new_phone_form.phone,
          selected_delivery_method: @new_phone_form.otp_delivery_preference,
        )
      else
        flash[:error] = t('errors.messages.phone_duplicate')
        redirect_to phone_setup_url
      end
    end

    def new_phone_form_params
      params.require(:new_phone_form).permit(
        :phone,
        :international_code,
        :otp_delivery_preference,
        :otp_make_default_number,
      )
    end
  end
end
