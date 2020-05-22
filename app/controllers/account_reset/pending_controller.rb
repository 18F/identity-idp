module AccountReset
  class PendingController < ApplicationController
    before_action :confirm_account_reset_request_exists

    def show
      analytics.track_event event: 'account reset is pending', user_id: current_user.uuid
      @pending_presenter = AccountReset::PendingPresenter.new(pending_account_reset_request)
    end

    def cancel
      AccountReset::CancelRequestForUser.new(user).call
      # account_reset_request.update(cancelled_at: Time.zone.now)
      # current_user.confirmed_email_addresses.each do |email_address|
      #   UserMailer.account_reset_cancel(email_address).deliver_now
      # end
      redirect_to user_two_factor_authentication_url
    end

    private

    def confirm_account_reset_request_exists
      render_not_found if pending_account_reset_request.blank?
    end

    def pending_account_reset_request
      @account_reset_request ||= AccountReset::FindPendingRequestForUser.new(
        current_user,
      ).call
    end
  end
end
