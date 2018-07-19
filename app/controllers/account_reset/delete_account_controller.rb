module AccountReset
  class DeleteAccountController < ApplicationController
    before_action :check_feature_enabled
    before_action :prevent_parameter_leak, only: :show
    before_action :check_granted_token

    def show; end

    def delete
      analytics.track_event(Analytics::ACCOUNT_RESET, event: :delete, token_valid: true)
      email = reset_session_and_set_email
      UserMailer.account_reset_complete(email).deliver_later
      redirect_to account_reset_confirm_delete_account_url
    end

    private

    def check_feature_enabled
      redirect_to root_url unless FeatureManagement.account_reset_enabled?
    end

    def reset_session_and_set_email
      user = @account_reset_request.user
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
      if AccountResetRequest.find_by(granted_token: token)&.granted_token_valid?
        session[:granted_token] = token
        redirect_to url_for
      else
        redirect_to root_url
      end
    end
  end
end
