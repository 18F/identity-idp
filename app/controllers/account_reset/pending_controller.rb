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

    def cancel
      analytics.pending_account_reset_cancelled
      AccountReset::PendingRequestForUser.new(current_user).cancel_account_reset_request!(
        account_reset_request_id: pending_account_reset_request.id,
        cancelled_at: Time.zone.now,
      )
    end

    private

    def confirm_account_reset_request_exists
      render_not_found if pending_account_reset_request.blank?
    end

    def pending_account_reset_request
      @pending_account_reset_request ||= AccountReset::PendingRequestForUser.new(
        current_user,
      ).get_account_reset_request
    end
  end
end
