module TwoFactorAuthentication
  class SmsOptInController < ApplicationController
    before_action :load_phone

    def new
      @other_mfa_options_url = other_options_mfa_url
      @cancel_url = cancel_url

      analytics.track_event(
        Analytics::SMS_OPT_IN_VISIT,
        new_user: new_user?,
        has_other_auth_methods: has_other_auth_methods?,
        phone_configuration_id: @phone_configuration.id,
      )
    end

    def create
      response = opt_out_manager.opt_in_phone_number(@phone_configuration.formatted_phone)

      analytics.track_event(
        Analytics::SMS_OPT_IN_SUBMITTED,
        response.to_h.merge(
          new_user: new_user?,
          has_other_auth_methods: has_other_auth_methods?,
          phone_configuration_id: @phone_configuration.id,
        ),
      )

      if response.success?
        @phone_number_opt_out.opt_in
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
      Telephony::Pinpoint::OptOutManager.new
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end

    def load_phone
      @phone_number_opt_out = PhoneNumberOptOut.from_param(params[:opt_out_uuid])
      @phone_configuration = mfa_context.phone_configurations.find do |phone_config|
        phone_config.formatted_phone == @phone_number_opt_out.formatted_phone
      end || PhoneConfiguration.new(phone: @phone_number_opt_out.formatted_phone)
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def other_options_mfa_url
      if new_user?
        authentication_methods_setup_path
      elsif has_other_auth_methods? && !user_fully_authenticated?
        login_two_factor_options_path
      end
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

    def has_other_auth_methods?
      two_factor_configurations.
        any? { |config| config.mfa_enabled? && config != @phone_configuration }
    end

    def new_user?
      two_factor_configurations.none?
    end

    def two_factor_configurations
      @two_factor_configurations ||= mfa_context.two_factor_configurations
    end
  end
end
