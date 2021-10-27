module Accounts
  class ConnectedAccountsController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated

    layout 'account_side_nav'

    def show
      @view_model = AccountShow.new(
        decrypted_pii: nil,
        personal_key: flash[:personal_key],
        sp_session_request_url: sp_session_request_url_without_prompt_login,
        sp_name: decorated_session.sp_name,
        decorated_user: current_user.decorate,
        locked_for_session: pii_locked_for_session?(current_user),
      )
    end
  end
end
