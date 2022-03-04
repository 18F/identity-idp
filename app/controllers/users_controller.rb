class UsersController < ApplicationController
  before_action :ensure_in_setup

  def destroy
    track_account_deletion_event
    url_after_cancellation = decorated_session.cancel_link_url
    destroy_user
    flash[:success] = t('sign_up.cancel.success')
    redirect_to url_after_cancellation
  end

  private

  def track_account_deletion_event
    properties = ParseControllerFromReferer.new(request.referer).call
    analytics.account_deletion(**properties)
  end

  def destroy_user
    user = current_user || User.find_by(confirmation_token: session[:user_confirmation_token])
    user&.destroy!
    sign_out if user
  end

  def ensure_in_setup
    redirect_to root_url if !session[:user_confirmation_token] && two_factor_enabled
  end

  def two_factor_enabled
    current_user && MfaPolicy.new(current_user).two_factor_enabled?
  end
end
