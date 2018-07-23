module AccountReset
  class CancelController < ApplicationController
    def cancel
      account_reset = AccountResetService.cancel_request(params[:token])
      if account_reset
        handle_success(account_reset.user)
      else
        handle_failure
      end
      redirect_to root_url
    end

    private

    def handle_success(user)
      analytics.track_event(Analytics::ACCOUNT_RESET,
                            event: :cancel, token_valid: true, user_id: user.uuid)
      sign_out if current_user
      UserMailer.account_reset_cancel(user.email).deliver_later
      phone = user.phone
      SmsAccountResetCancellationNotifierJob.perform_now(phone: phone) if phone.present?
      flash[:success] = t('devise.two_factor_authentication.account_reset.successful_cancel')
    end

    def handle_failure
      return if params[:token].blank?
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :cancel, token_valid: false)
    end
  end
end
