module AccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable
    include ActionView::Helpers::DateHelper

    before_action :confirm_two_factor_enabled

    def show
      analytics.account_reset_visit
      @account_reset_deletion_period_interval = account_reset_deletion_period_interval
    end

    def create
      create_account_reset_request
      flash[:email] = current_user.email_addresses.take.email

      redirect_to account_reset_confirm_request_url
    end

    private

    def create_account_reset_request
      response = AccountReset::CreateRequest.new(current_user, sp_session[:issuer]).call
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

    def account_reset_deletion_period_interval
      current_time = Time.zone.now

      distance_of_time_in_words(
        current_time,
        current_time + IdentityConfig.store.account_reset_wait_period_days.days,
        true,
        accumulate_on: :hours,
      )
    end
  end
end
