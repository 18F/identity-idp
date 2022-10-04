module TwoFactorAuthentication
  class OptionsController < ApplicationController
    include TwoFactorAuthenticatable

    FACTOR_TO_URL_METHOD = {
      'voice' => :otp_send_url,
      'sms' => :otp_send_url,
      'phone' => :otp_send_url,
      'auth_app' => :login_two_factor_authenticator_url,
      'piv_cac' => :login_two_factor_piv_cac_url,
      'webauthn' => :login_two_factor_webauthn_url,
      'webauthn_platform' => :login_two_factor_webauthn_url,
      'personal_key' => :login_two_factor_personal_key_url,
      'backup_code' => :login_two_factor_backup_code_url,
    }.freeze

    EXTRA_URL_OPTIONS = {
      'voice' => {
        otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
      },
      'sms' => {
        otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
      },
    }.freeze

    def index
      @two_factor_options_form = TwoFactorLoginOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.multi_factor_auth_option_list_visit
    end

    def create
      @two_factor_options_form = TwoFactorLoginOptionsForm.new(current_user)
      result = @two_factor_options_form.submit(two_factor_options_form_params)
      analytics.multi_factor_auth_option_list(**result.to_h)

      if result.success?
        process_valid_form
      else
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    private

    def two_factor_options_presenter
      TwoFactorLoginOptionsPresenter.new(
        user: current_user,
        view: view_context,
        user_session_context: context,
        service_provider: current_sp,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_form
      url = mfa_redirect_url
      redirect_to url if url.present?
    end

    def mfa_redirect_url
      selection = @two_factor_options_form.selection
      options = EXTRA_URL_OPTIONS[selection] || {}

      configuration_id = @two_factor_options_form.configuration_id
      user_session[:phone_id] = configuration_id if configuration_id.present?
      options[:id] = user_session[:phone_id]
      options[:platform] = true if selection == 'webauthn_platform'

      build_url(selection, options)
    end

    def build_url(selection, options)
      method = FACTOR_TO_URL_METHOD[selection]
      public_send(method, options) if method.present?
    end

    def two_factor_options_form_params
      params.fetch(:two_factor_options_form, {}).permit(:selection)
    end
  end
end
