# frozen_string_literal: true

module AccountReset
  class DeleteAccountController < ApplicationController
    def show
      render :show and return unless token

      result = AccountReset::ValidateGrantedToken.new(token, request, analytics).call
      analytics.account_reset_granted_token_validation(**result)

      if result.success?
        handle_valid_token
      else
        handle_invalid_token(result)
      end
    end

    def cancel
      result = AccountReset::Cancel.new(session[:granted_token]).call
      analytics.account_reset_cancel(**result)

      if result.success?
        flash[:success] = t(
          'two_factor_authentication.account_reset.successful_cancel',
          app_name: APP_NAME,
        )
      end
      redirect_to root_url
    end

    def delete
      granted_token = session.delete(:granted_token)
      result = AccountReset::DeleteAccount.new(granted_token, request, analytics).call

      analytics.account_reset_delete(**result.to_h.except(:email))
      attempts_api_tracker.account_reset_account_deleted(
        success: result.success?,
        failure_reason: attempts_api_tracker.parse_failure_reason(result),
      )

      if result.success?
        handle_successful_deletion(result)
      else
        handle_invalid_token(result)
      end
    end

    private

    def token
      params[:token]
    end

    def handle_valid_token
      session[:granted_token] = token
      redirect_to url_for
    end

    def handle_invalid_token(result)
      flash[:error] = result.errors[:token].first
      redirect_to root_url
    end

    def handle_successful_deletion(result)
      sign_out
      flash[:email] = result.extra[:email]
      redirect_to account_reset_confirm_delete_account_url
    end
  end
end
