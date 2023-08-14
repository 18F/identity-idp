module Users
  class PhoneSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include UserAuthenticator
    include PhoneConfirmation
    include MfaSetupConcern
    include RecaptchaConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_setup_presenter
    before_action :allow_csp_recaptcha_src, if: :recaptcha_enabled?
    before_action :confirm_recently_authenticated_2fa


    helper_method :in_multi_mfa_selection_flow?

    def index
      @new_phone_form = NewPhoneForm.new(
        user: current_user,
        analytics: analytics,
        setup_voice_preference: setup_voice_preference?,
      )
      track_phone_setup_visit
    end

    def create
      @new_phone_form = NewPhoneForm.new(user: current_user, analytics: analytics)
      result = @new_phone_form.submit(new_phone_form_params)
      analytics.multi_factor_auth_phone_setup(**result.to_h)

      if result.success?
        handle_create_success(@new_phone_form.phone)
      elsif recoverable_recaptcha_error?(result)
        render :spam_protection, locals: { two_factor_options_path: two_factor_options_path }
      else
        render :index
      end
    end

    private

    def recaptcha_enabled?
      FeatureManagement.phone_recaptcha_enabled?
    end

    def track_phone_setup_visit
      mfa_user = MfaContext.new(current_user)
      if in_multi_mfa_selection_flow?
        analytics.user_registration_phone_setup_visit(
          enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
        )
      else
        analytics.add_phone_setup_visit
      end
    end

    def set_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def setup_voice_preference?
      params[:otp_delivery_preference].to_s == 'voice'
    end

    def handle_create_success(phone)
      if MfaContext.new(current_user).phone_configurations.map(&:phone).index(phone).nil?
        prompt_to_confirm_phone(
          id: nil,
          phone: @new_phone_form.phone,
          selected_delivery_method: @new_phone_form.otp_delivery_preference,
          phone_type: @new_phone_form.phone_info&.type,
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
        :recaptcha_token,
        :recaptcha_version,
        :recaptcha_mock_score,
      )
    end
  end
end
