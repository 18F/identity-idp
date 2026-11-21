# frozen_string_literal: true

module AccountRecovery
  # The session token keeps the password URL clean; it does not authenticate
  # the user. Only a correct password consumes it and creates a pre-2FA session.
  class VerifyController < ApplicationController
    before_action :verify_link, if: :link_evidence_present?
    before_action :confirm_recovery_request
    before_action :confirm_password_form, only: :create

    def show
      if token_param
        redirect_to account_recovery_verify_url
      elsif session_token
        render_password_form
      else
        redirect_to account_recovery_new_mfa_setup_url
      end
    end

    def create
      return handle_rate_limited_password if password_rate_limiter.limited?

      result = AccountRecovery::VerifyPassword.new(
        account_recovery_request: account_recovery_request,
        password: password,
      ).call

      analytics.account_recovery_password_verification(**result.to_h)

      if result.success?
        handle_password_verified
      elsif result.errors.key?(:password)
        handle_incorrect_password
      else
        handle_invalid_token
      end
    end

    private

    def link_evidence_present?
      action_name == 'create' || token_param.present? || session_token.present?
    end

    def token_param
      params[:token].presence if action_name == 'show'
    end

    def session_token
      session[:account_recovery_granted_token]
    end

    def verify_link
      token = token_param || session_token

      return handle_rate_limited_token if token_rate_limiter.limited?

      token_rate_limiter.increment!

      verifier = AccountRecovery::VerifyLink.new(token: token)
      result = verifier.call

      analytics.account_recovery_link_validation(**result.to_h)

      return handle_invalid_token unless result.success?

      # Only a link that proved valid ends the current session, so a request carrying an invalid
      # token cannot be used to sign out whoever happens to be signed in on this browser.
      sign_out if user_signed_in?

      @account_recovery_request = verifier.account_recovery_request
      session[:account_recovery_granted_token] = token
    end

    def handle_invalid_token
      session.delete(:account_recovery_granted_token)
      flash[:error] = t('account_recovery.verify.token_invalid')
      redirect_to root_url
    end

    def handle_rate_limited_token
      session.delete(:account_recovery_granted_token)
      analytics.account_recovery_link_validation(success: false, rate_limited: true)

      flash[:error] = t('account_recovery.verify.token_rate_limited')
      redirect_to root_url
    end

    def handle_password_verified
      password_rate_limiter.reset!
      session.delete(:account_recovery_granted_token)
      sign_in_partially

      redirect_to account_recovery_new_mfa_setup_url
    end

    def handle_incorrect_password
      password_rate_limiter.increment!

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

    def render_password_form
      @email = recovery_user.last_sign_in_email_address&.email
      render :show
    end

    def confirm_recovery_request
      render_not_found if account_recovery_request.blank?
    end

    def confirm_password_form
      return if params[:request_id].to_s == account_recovery_request.id.to_s

      handle_invalid_token
    end

    def account_recovery_request
      return @account_recovery_request if defined?(@account_recovery_request)
      return unless user_signed_in?

      @account_recovery_request = AccountRecoveryRequest.password_verified_for_user(current_user)
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
