module TwoFactorAuthentication
  class OptionsController < ApplicationController
    include TwoFactorAuthenticatable

    def index
      @two_factor_options_form = TwoFactorLoginOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_OPTION_LIST_VISIT)
    end

    def create
      @two_factor_options_form = TwoFactorLoginOptionsForm.new(current_user)
      result = @two_factor_options_form.submit(two_factor_options_form_params)
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_OPTION_LIST, result.to_h)

      if result.success?
        process_valid_form
      else
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    private

    def two_factor_options_presenter
      TwoFactorLoginOptionsPresenter.new(current_user, view_context, current_sp)
    end

    def process_valid_form
      factor_to_url = {
        'voice' =>  otp_send_url(otp_delivery_selection_form: { otp_delivery_preference: 'voice' }),
        'personal_key' => login_two_factor_personal_key_url,
        'sms' => otp_send_url(otp_delivery_selection_form: { otp_delivery_preference: 'sms' }),
        'auth_app' => login_two_factor_authenticator_url,
        'piv_cac' => FeatureManagement.piv_cac_enabled? ? login_two_factor_piv_cac_url : nil,
        'webauthn' => FeatureManagement.webauthn_enabled? ? login_two_factor_webauthn_url : nil,
      }
      url = factor_to_url[@two_factor_options_form.selection]
      redirect_to url if url
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection)
    end
  end
end
