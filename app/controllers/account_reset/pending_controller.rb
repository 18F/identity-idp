module AccountReset
  class PendingController < ApplicationController
    include UserAuthenticator

    before_action :authenticate_user
    before_action :confirm_account_reset_request_exists

    def show
      analytics.track_event(Analytics::PENDING_ACCOUNT_RESET_VISITED)
      @pending_presenter = AccountReset::PendingPresenter.new(pending_account_reset_request)
    end

    def confirm; end

    def cancel
      analytics.track_event(Analytics::PENDING_ACCOUNT_RESET_CANCELLED)
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
