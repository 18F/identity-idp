module AccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled

    def show
      analytics.account_reset_visit
    end

    def create
      create_account_reset_request
      flash[:email] = current_user.email_addresses.take.email
      
      redirect_to account_reset_confirm_request_url
    end

    private

    def create_account_reset_request
      response = AccountReset::CreateRequest.new(current_user).call
      irs_attempts_api_tracker.account_reset_request_submitted(
        success: response.success?,
      )
      analytics.account_reset_request(**response.to_h, **analytics_attributes)
    end

    def confirm_two_factor_enabled
      return if MfaPolicy.new(current_user).two_factor_enabled?

      redirect_to authentication_methods_setup_url
    end

    def analytics_attributes
      {
        sms_phone: TwoFactorAuthentication::PhonePolicy.new(current_user).configured?,
        totp: TwoFactorAuthentication::AuthAppPolicy.new(current_user).configured?,
        piv_cac: TwoFactorAuthentication::PivCacPolicy.new(current_user).configured?,
        email_addresses: current_user.email_addresses.count,
      }
    end
  end
end
