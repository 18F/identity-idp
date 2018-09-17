module AccountReset
  class CancelController < ApplicationController
    before_action :check_feature_enabled

    def show
      return render :show unless token

      result = AccountReset::ValidateCancelToken.new(token).call
      track_event(result)

      if result.success?
        handle_valid_token
      else
        handle_invalid_token(result)
      end
    end

    def create
      result = AccountReset::Cancel.new(session[:cancel_token]).call

      track_event(result)

      handle_success if result.success?

      redirect_to root_url
    end

    private

    def check_feature_enabled
      redirect_to root_url unless FeatureManagement.account_reset_enabled?
    end

    def track_event(result)
      analytics.track_event(Analytics::ACCOUNT_RESET, result.to_h)
    end

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
      flash[:success] = t('two_factor_authentication.account_reset.successful_cancel')
    end

    def token
      params[:token]
    end
  end
end
