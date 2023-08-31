module AccountReset
  class CancelController < ApplicationController
    def show
      return render :show unless token

      result = AccountReset::ValidateCancelToken.new(token).call
      analytics.account_reset_cancel_token_validation(**result.to_h)

      if result.success?
        handle_valid_token
      else
        handle_invalid_token(result)
      end
    end

    def create
      result = AccountReset::Cancel.new(session[:cancel_token]).call

      analytics.account_reset_cancel(**result.to_h)
      irs_attempts_api_tracker.account_reset_cancel_request

      if result.success?
        handle_success
      else
        redirect_to root_url
      end
    end

    private

    def handle_valid_token
      session[:cancel_token] = token
      redirect_to url_for
    end

    def handle_invalid_token(result)
      flash[:error] = result.errors[:token].first
      redirect_to root_url
    end

    def handle_success
      sign_out if current_user
      flash[:success] = t(
        'two_factor_authentication.account_reset.successful_cancel',
        app_name: APP_NAME,
      )
      redirect_to root_url
    end

    def token
      params[:token]
    end
  end
end
