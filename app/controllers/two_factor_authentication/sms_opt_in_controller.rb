module TwoFactorAuthentication
  class SmsOptInController < ApplicationController
    def show
      # TODO: analytics

      @phone_configuration = phone_configuration
      @has_other_auth_methods = has_other_auth_methods?
    end

    def create
      response = opt_out_manager.opt_in_phone_number(phone_configuration.formatted_phone)

      # TODO: analytics

      if response.success?
        redirect_to otp_send_url(
          otp_delivery_selection_form: {
            otp_delivery_preference: :sms,
          },
        )
      else
        @error = 'error message here'

      end
    end

    private

    def opt_out_manager
      @opt_out_manager ||= Telephony::Pinpoint::OptOutManager.new
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end

    def phone_configuration
      if (phone_id = user_session[:phone_id]).present?
        mfa_context.phone_configuration(phone_id)
      elsif (unconfirmed_phone = user_session[:unconfirmed_phone]).present?
        PhoneConfiguration.new(phone: unconfirmed_phone)
      end
    end

    def has_other_auth_methods?
      mfa_context.enabled_mfa_configurations.
        select { |config| config != phone_configuration }.
        present?
    end
  end
end
