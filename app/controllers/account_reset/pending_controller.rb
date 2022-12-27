module AccountReset
  class PendingController < ApplicationController
    include UserAuthenticator

    before_action :authenticate_user
    before_action :confirm_account_reset_request_exists

    def show
      analytics.pending_account_reset_visited
      @pending_presenter = AccountReset::PendingPresenter.new(pending_account_reset_request)
    end

    def confirm; end

    def cancel
      analytics.pending_account_reset_cancelled
      irs_attempts_api_tracker.account_reset_cancel_request
      AccountReset::CancelRequestForUser.new(current_user).call
    end

    private

    def confirm_account_reset_request_exists
      render_not_found if pending_account_reset_request.blank?
    end

    def pending_account_reset_request
      @pending_account_reset_request ||= AccountReset::FindPendingRequestForUser.new(
        current_user,
      ).call
    end
  end
end
