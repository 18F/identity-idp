module AccountReset
  class CancelController < ApplicationController
    def create
      result = CancelAccountResetRequest.new(params[:token]).call

      analytics.track_event(Analytics::ACCOUNT_RESET, result.to_h)

      handle_success if result.success?

      redirect_to root_url
    end

    private

    def handle_success
      sign_out if current_user
      flash[:success] = t('devise.two_factor_authentication.account_reset.successful_cancel')
    end
  end
end
