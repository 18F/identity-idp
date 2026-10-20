# frozen_string_literal: true

module AccountRecovery
  # A correct password creates a partial, pre-2FA session. The user is
  # recognized and routed, but `NEED_AUTHENTICATION` stays true, so every
  # surface guarded by `confirm_two_factor_authenticated` stays closed and no
  # service provider assertion can be released. The emailed link and the
  # password never add up to a fully authenticated session.
  class VerifyController < ApplicationController
    before_action :prevent_token_referrer
    before_action :verify_token, if: -> { action_name == 'create' || token_param }
    before_action :confirm_recovery_request

    def show
      if token_param
        render_password_form
      else
        render :pending_mfa_setup
      end
    end

    def create
      return handle_rate_limited_password if password_rate_limiter.limited?

      if recovery_user.valid_password?(password)
        handle_valid_password
      else
        handle_invalid_password
      end
    end

    private

    def token_param
      params[:token].presence
    end

    # `no-referrer` makes browsers send `Origin: null` on the form POST, which
    # fails Rails' CSRF origin check. `strict-origin` still keeps the token out
    # of the Referer header by sending only the scheme and host.
    def prevent_token_referrer
      response.headers['Referrer-Policy'] = 'strict-origin'
    end

    def verify_token
      sign_out if user_signed_in?

      return handle_rate_limited_token if token_rate_limiter.limited?

      token_rate_limiter.increment!

      validator = AccountRecovery::ValidateGrantedToken.new(token: token_param)
      result = validator.call

      analytics.account_recovery_link_validation(**result.to_h)

      if result.success?
        handle_valid_token(validator.account_recovery_request)
      else
        handle_invalid_token
      end
    end

    def handle_valid_token(recovery_request)
      recovery_request.with_lock do
        return handle_invalid_token unless valid_token?(recovery_request)

        if recovery_request.state == AccountRecoveryRequest::GRANTED
          recovery_request.transition_to!(AccountRecoveryRequest::LINK_VERIFIED)
        end
      end
      @account_recovery_request = recovery_request
    end

    def handle_invalid_token
      flash[:error] = t('account_recovery.verify.token_invalid')
      redirect_to root_url
    end

    def handle_rate_limited_token
      analytics.account_recovery_link_validation(success: false, rate_limited: true)

      flash[:error] = t('account_recovery.verify.token_rate_limited')
      redirect_to root_url
    end

    def handle_valid_password
      # Recheck under the row lock so expiry, token replacement, and concurrent
      # password submissions cannot create a session from stale token evidence.
      account_recovery_request.with_lock do
        return handle_invalid_token unless valid_token?(account_recovery_request)
        return handle_invalid_token unless account_recovery_request.transition_to!(
          AccountRecoveryRequest::PASSWORD_VERIFIED,
          token_fingerprint: nil,
          token_expires_at: nil,
        )
      end

      password_rate_limiter.reset!
      analytics.account_recovery_password_verification(success: true)

      sign_in_partially

      redirect_to account_recovery_verify_url
    end

    def handle_invalid_password
      password_rate_limiter.increment!

      analytics.account_recovery_password_verification(success: false)

      flash.now[:error] = t('errors.confirm_password_incorrect')
      render_password_form
    end

    def handle_rate_limited_password
      analytics.account_recovery_password_verification(success: false, rate_limited: true)

      flash[:error] = t('account_recovery.verify.password_rate_limited')
      redirect_to root_url
    end

    # Establishes a partial session only.
    def sign_in_partially
      sign_in(:user, recovery_user)

      user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = true
    end

    def valid_token?(recovery_request)
      validator = AccountRecovery::ValidateGrantedToken.new(token: token_param)
      validator.call.success? && validator.account_recovery_request == recovery_request
    end

    def render_password_form
      @token = token_param
      @email = recovery_user.last_sign_in_email_address&.email
      render :show
    end

    def confirm_recovery_request
      render_not_found if account_recovery_request.blank?
    end

    # Before password verification, only the submitted token selects the ARR.
    # The token-free continuation requires a signed-in owner and verified password.
    def account_recovery_request
      return @account_recovery_request if defined?(@account_recovery_request)
      return unless user_signed_in?

      @account_recovery_request = AccountRecoveryRequest.active.find_by(
        user: current_user,
        state: AccountRecoveryRequest::PASSWORD_VERIFIED,
      )
    end

    def recovery_user
      account_recovery_request.user
    end

    def password
      params.require(:user)[:password]
    end

    def token_rate_limiter
      @token_rate_limiter ||= RateLimiter.new(
        target: request.ip,
        rate_limit_type: :account_recovery_verify_token,
      )
    end

    def password_rate_limiter
      @password_rate_limiter ||= RateLimiter.new(
        user: recovery_user,
        rate_limit_type: :account_recovery_verify_password,
      )
    end
  end
end
