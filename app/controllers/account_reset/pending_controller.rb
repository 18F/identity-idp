module AccountReset
  class PendingController < ApplicationController
    include PendingAccountResetRequestConcern

    before_action :render_404_if_request_missing

    def show
      analytics.track_event event: 'account reset is pending', user_id: current_user.uuid

      @pending_presenter = AccountReset::PendingPresenter.new(account_reset_request)
    end

    def cancel
      account_reset_request.update(cancelled_at: Time.zone.now)
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_reset_cancel(email_address).deliver_now
      end
      redirect_to user_two_factor_authentication_url
    rescue StandardError
      flash[:error] = t('account_reset.pending.cancel_error')
      redirect_to account_reset_pending_url
    end

    private

    def render_404_if_request_missing
      render_not_found unless account_reset_request
    end

    def account_reset_request
      @account_reset_request ||= pending_account_reset_request(current_user)
    end
  end
end
