module TwoFactorAuthentication
  class SmsOptInController < ApplicationController
    before_action :load_phone_configuration

    def new
      @has_other_auth_methods = has_other_auth_methods?

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
        @has_other_auth_methods = has_other_auth_methods?

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
        @mode = :auth
        @phone_configuration = mfa_context.phone_configuration(phone_id)
      elsif user_session.present? && (unconfirmed_phone = user_session[:unconfirmed_phone]).present?
        @mode = :confirmation
        @phone_configuration = PhoneConfiguration.new(phone: unconfirmed_phone)
      else
        render_not_found
      end
    end

    def has_other_auth_methods?
      mfa_context.two_factor_configurations.
        select { |config| config.mfa_enabled? && config != @phone_configuration }.
        present?
    end
  end
end
