class UsersController < ApplicationController
  def destroy
    track_account_deletion_event
    url_after_cancellation = decorated_session.cancel_link_url
    destroy_user
    flash[:success] = t('sign_up.cancel.success')
    redirect_to url_after_cancellation
  end

  private

  def track_account_deletion_event
    controller_and_action_from_referer = ParseControllerFromReferer.new(request.referer).call
    properties = {
      request_came_from: controller_and_action_from_referer,
    }
    analytics.track_event(Analytics::ACCOUNT_DELETION, properties)
  end

  def destroy_user
    user = current_user || User.find_by(confirmation_token: session[:user_confirmation_token])
    user&.destroy!
    sign_out if user
  end
end
