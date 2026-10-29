# frozen_string_literal: true

module DestructiveAccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable
    include DestructiveAccountResetConcern

    before_action :confirm_two_factor_enabled
    before_action :confirm_legacy_account_reset_allowed

    def show
      analytics.account_reset_visit
      @account_reset_deletion_period_interval = account_reset_deletion_period_interval(current_user)
    end

    def create
      rate_limiter = RateLimiter.new(user: current_user, rate_limit_type: :account_reset_request)
      rate_limiter.increment!

      unless account_reset_max_attempts_exceeded? || rate_limiter.limited?
        return redirect_to(login_two_factor_options_url) if !create_account_reset_request.success?
      end
      flash[:email] = current_user.email_addresses.take.email

      redirect_to account_reset_confirm_request_url
    end

    private

    def create_account_reset_request
      response = DestructiveAccountReset::CreateRequest.new(current_user, sp_session[:issuer]).call
      analytics.account_reset_request(**response, **analytics_attributes)
      flash[:error] = t('errors.general') if !response.success?
      response
    end

    def confirm_two_factor_enabled
      return if MfaPolicy.new(current_user).two_factor_enabled?

      redirect_to authentication_methods_setup_url
    end

    def account_reset_max_attempts_exceeded?
      rate_limiter = RateLimiter.new(
        user: current_user,
        rate_limit_type: :account_reset_max_attempts,
      )
      rate_limiter.increment!
      rate_limiter.limited?
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
