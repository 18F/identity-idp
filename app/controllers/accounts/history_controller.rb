# frozen_string_literal: true

module Accounts
  class HistoryController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated

    layout 'account_side_nav'

    def show
      @presenter = AccountShowPresenter.new(
        decrypted_pii: nil,
        sp_session_request_url: sp_session_request_url_with_updated_params,
        authn_context: resolved_authn_context_result,
        sp_name: decorated_sp_session.sp_name,
        user: current_user,
        locked_for_session: pii_locked_for_session?(current_user),
        requested_attributes: nil,
        ial2_requested: nil,
      )
    end
  end
end
