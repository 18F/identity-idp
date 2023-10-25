# frozen_string_literal: true

module Accounts
  class TwoFactorAuthenticationController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated

    layout 'account_side_nav'

    def show
      session[:account_redirect_path] = account_two_factor_authentication_path
      @presenter = AccountShowPresenter.new(
        decrypted_pii: nil,
        personal_key: flash[:personal_key],
        sp_session_request_url: sp_session_request_url_with_updated_params,
        sp_name: decorated_sp_session.sp_name,
        user: current_user,
        locked_for_session: pii_locked_for_session?(current_user),
      )
    end
  end
end
