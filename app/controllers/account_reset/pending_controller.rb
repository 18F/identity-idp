module AccountReset
  class PendingController < ApplicationController
    include PendingAccountResetRequestConcern

    before_action :render_404_if_request_missing

    def show
      analytics.track_event({
        event: 'account reset is pending',
        user_id: current_user.uuid,
      })
      @pending_presenter = AccountReset::PendingPresenter.new(account_reset_request)
    end

    def cancel
      rec_to_cancel = AccountResetRequest.find_by_id(params[:id])
      pp rec_to_cancel
      rec_to_cancel.cancelled_at = Time.zone.now
      rec_to_cancel.save!
      # this is wrong; needs to at least send 'successful cancel' email to user
      # but do we need to flash a message on the UI first?
      redirect_to user_two_factor_authentication_url
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
