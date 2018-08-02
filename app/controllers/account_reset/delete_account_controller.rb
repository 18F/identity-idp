module AccountReset
  class DeleteAccountController < ApplicationController
    before_action :check_feature_enabled
    before_action :prevent_parameter_leak, only: :show
    before_action :check_granted_token

    def show; end

    def delete
      user = @account_reset_request.user
      analytics.track_event(Analytics::ACCOUNT_RESET,
                            event: :delete, token_valid: true, user_id: user.uuid)
      email = reset_session_and_set_email(user)
      UserMailer.account_reset_complete(email).deliver_later
      redirect_to account_reset_confirm_delete_account_url
    end

    private

    def check_feature_enabled
      redirect_to root_url unless FeatureManagement.account_reset_enabled?
    end

    def reset_session_and_set_email(user)
      email = user.email
      user.destroy!
      sign_out
      flash[:email] = email
    end

    def check_granted_token
      @account_reset_request = AccountResetRequest.from_valid_granted_token(session[:granted_token])
      return if @account_reset_request
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :delete, token_valid: false)
      redirect_to root_url
    end

    def prevent_parameter_leak
      token = params[:token]
      return if token.blank?
      remove_token_from_url(token)
    end

    def remove_token_from_url(token)
      ar = AccountResetRequest.find_by(granted_token: token)
      if ar&.granted_token_valid?
        session[:granted_token] = token
        redirect_to url_for
        return
      end
      handle_expired_token(ar) if ar&.granted_token_expired?
      redirect_to root_url
    end

    def handle_expired_token(ar)
      analytics.track_event(Analytics::ACCOUNT_RESET,
                            event: :delete,
                            token_valid: true,
                            expired: true,
                            user_id: ar&.user&.uuid)
      flash[:error] = link_expired
    end

    def link_expired
      t('devise.two_factor_authentication.account_reset.link_expired')
    end
  end
end
