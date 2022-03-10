module AccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled

    def show
      analytics.track_event(Analytics::ACCOUNT_RESET_VISIT)
    end

    def create
      create_account_reset_request
      flash[:email] = current_user.email_addresses.take.email
      redirect_to account_reset_confirm_request_url
    end

    private

    def create_account_reset_request
      response = AccountReset::CreateRequest.new(current_user).call
      analytics.account_reset(**response.to_h.merge(analytics_attributes))
    end

    def confirm_two_factor_enabled
      return if MfaPolicy.new(current_user).two_factor_enabled?

      redirect_to two_factor_options_url
    end

    def analytics_attributes
      {
        event: 'request',
        sms_phone: TwoFactorAuthentication::PhonePolicy.new(current_user).configured?,
        totp: TwoFactorAuthentication::AuthAppPolicy.new(current_user).configured?,
        piv_cac: TwoFactorAuthentication::PivCacPolicy.new(current_user).configured?,
        email_addresses: current_user.email_addresses.count,
      }
    end
  end
end
