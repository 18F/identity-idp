module TwoFactorAuthentication
  class SmsOptInController < ApplicationController
    before_action :load_phone_configuration

    def new
      @other_mfa_options_url = other_options_mfa_url
      @cancel_url = cancel_url

      analytics.track_event(
        Analytics::SMS_OPT_IN_VISIT,
        has_other_auth_methods: @has_other_auth_methods,
        phone_configuration_id: @phone_configuration.id,
      )
    end

    def create
      response = opt_out_manager.opt_in_phone_number(@phone_configuration.formatted_phone)

      analytics.track_event(
        Analytics::SMS_OPT_IN_SUBMITTED,
        response.to_h.merge(phone_configuration_id: @phone_configuration.id),
      )

      if response.success?
        redirect_to otp_send_url(otp_delivery_selection_form: { otp_delivery_preference: :sms })
      else
        @other_mfa_options_url = other_options_mfa_url
        @cancel_url = cancel_url

        if !response.error
          # unsuccessful, but didn't throw an exception: already opted in last 30 days
          render :error
        else
          # one-off error, show form so users can try again
          flash[:error] = t('two_factor_authentication.opt_in.error_retry')
          render :new
        end
      end
    end

    private

    def opt_out_manager
      @opt_out_manager ||= Telephony::Pinpoint::OptOutManager.new
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end

    def load_phone_configuration
      if user_session.present? && (phone_id = user_session[:phone_id]).present?
        @phone_configuration = mfa_context.phone_configuration(phone_id)
      elsif user_session.present? && (unconfirmed_phone = user_session[:unconfirmed_phone]).present?
        @phone_configuration = PhoneConfiguration.new(phone: unconfirmed_phone)
      else
        render_not_found
      end
    end

    def other_options_mfa_url
      if new_user?
        two_factor_options_path
      elsif has_other_auth_methods?
        login_two_factor_options_path
      end
    end

    def has_other_auth_methods?
      mfa_context.two_factor_configurations.
        any? { |config| config.mfa_enabled? && config != @phone_configuration }
    end

    def new_user?
      mfa_context.two_factor_configurations.none?
    end

    def cancel_url
      if user_fully_authenticated?
        account_path
      elsif decorated_session.sp_name
        return_to_sp_cancel_path
      else
        sign_out_path
      end
    end
  end
end
