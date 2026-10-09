# frozen_string_literal: true

module Accounts
  # Account > Delegated access: the person's standing approvals for service providers to act for
  # them at agency applications, with the controls to approve more or revoke.
  class DelegatedAccessController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated

    layout 'account_side_nav'

    def show
      analytics.delegated_access_page_visited
      # The side-navigation layout reads the account presenter for its header; the page itself
      # is built from the delegated-access presenter.
      @presenter = AccountShowPresenter.new(
        decrypted_pii: nil,
        sp_session_request_url: sp_session_request_url_with_updated_params,
        authn_context: resolved_authn_context_result,
        sp_name: decorated_sp_session.sp_name,
        user: current_user,
        locked_for_session: pii_locked_for_session?(current_user),
      )
      @delegated_access = DelegatedAccessPresenter.new(user: current_user)
    end
  end
end
