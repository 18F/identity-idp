# frozen_string_literal: true

module AccountReset
  class PendingController < ApplicationController
    include UserAuthenticator
    include AccountResetConcern

    before_action :authenticate_user
    before_action :confirm_account_reset_request_exists

    def show
      analytics.pending_account_reset_visited
      @pending_presenter = AccountReset::PendingPresenter.new(pending_account_reset_request)
    end

    def confirm
      @account_reset_deletion_period_interval = account_reset_deletion_period_interval(current_user)
    end

    def cancel
      analytics.pending_account_reset_cancelled
      irs_attempts_api_tracker.account_reset_cancel_request
      pending_account_reset_request.cancel!
    end

    private

    def confirm_account_reset_request_exists
      render_not_found if pending_account_reset_request.blank?
    end

    def pending_account_reset_request
      @pending_account_reset_request ||= AccountResetRequest.pending_request_for(current_user)
    end
  end
end
