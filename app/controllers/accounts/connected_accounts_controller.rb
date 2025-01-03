# frozen_string_literal: true

module Accounts
  class ConnectedAccountsController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated

    layout 'account_side_nav'

    def show
      analytics.connected_accounts_page_visited
      @presenter = AccountShowPresenter.new(
        decrypted_pii: nil,
        sp_session_request_url: sp_session_request_url_with_updated_params,
        authn_context: resolved_authn_context_result,
        sp_name: decorated_sp_session.sp_name,
        user: current_user,
        locked_for_session: pii_locked_for_session?(current_user),
        requested_attributes: requested_attributes,
      )
    end

    private

    def requested_attributes
      if decorated_sp_session.requested_attributes.present?
        decorated_sp_session.requested_attributes.map(&:to_sym)
      end
    end
  end
end
