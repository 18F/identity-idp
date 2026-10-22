# frozen_string_literal: true

module AccountRecovery
  # The session token keeps the password URL clean; it does not authenticate
  # the user. Only a correct password consumes it and creates a pre-2FA session.
  class VerifyController < ApplicationController
    before_action :verify_token, if: -> {
      action_name == 'create' || token_param || session[:account_recovery_granted_token]
    }
    before_action :confirm_recovery_request
    before_action :confirm_password_form, only: :create

    def show
      if token_param
        redirect_to account_recovery_verify_url
      elsif session[:account_recovery_granted_token]
        render_password_form
      else
        redirect_to account_recovery_new_mfa_setup_url
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
      params[:token].presence if action_name == 'show'
    end

    def verify_token
      @token = token_param || session[:account_recovery_granted_token]
      sign_out if user_signed_in?

      return handle_rate_limited_token if token_rate_limiter.limited?

      token_rate_limiter.increment!

      validator = AccountRecovery::ValidateGrantedToken.new(token: @token)
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
      session[:account_recovery_granted_token] = @token
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

    def handle_valid_password
      # Consume the token atomically only after the password succeeds.
      account_recovery_request.with_lock do
        return handle_invalid_token unless valid_token?(account_recovery_request)
        return handle_invalid_token unless account_recovery_request.transition_to!(
          AccountRecoveryRequest::PASSWORD_VERIFIED,
          token_fingerprint: nil,
          token_expires_at: nil,
        )
        AccountRecovery::SuspendExistingMfa.new(
          account_recovery_request: account_recovery_request,
        ).call
      end

      password_rate_limiter.reset!
      analytics.account_recovery_password_verification(success: true)

      session.delete(:account_recovery_granted_token)
      sign_in_partially

      redirect_to account_recovery_new_mfa_setup_url
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

      %i[unconfirmed_phone phone_id new_totp_secret backup_codes mfa_selections
         next_mfa_selection_choice webauthn_challenge].each { |key| user_session.delete(key) }
      user_session[:context] = 'authentication'
      user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = true
    end

    def valid_token?(recovery_request)
      validator = AccountRecovery::ValidateGrantedToken.new(token: @token)
      validator.call.success? && validator.account_recovery_request == recovery_request
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

      @account_recovery_request = AccountRecoveryRequest.active.find_by(
        user: current_user,
        state: [AccountRecoveryRequest::PASSWORD_VERIFIED,
                AccountRecoveryRequest::REPLACEMENT_MFA_PENDING],
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
