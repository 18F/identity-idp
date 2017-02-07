module OpenidConnect
  class AuthorizationController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def index
      @authorize_form = build_authorize_form

      return redirect_to verify_url if identity_needs_verification?

      success = @authorize_form.valid?
      analytics.track_event(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                            success: success,
                            client_id: @authorize_form.client_id,
                            errors: @authorize_form.errors.messages)

      render(success ? :index : :error)
    end

    def create
      @authorize_form = OpenidConnectAuthorizeForm.new(session_params)

      result = @authorize_form.submit(current_user, session.id)
      analytics.track_event(Analytics::OPENID_CONNECT_ALLOW, result.except(:redirect_uri))

      if (redirect_uri = result[:redirect_uri])
        redirect_to redirect_uri
      else
        render :error
      end
    end

    def destroy
      @authorize_form = OpenidConnectAuthorizeForm.new(session_params)
      analytics.track_event(Analytics::OPENID_CONNECT_DECLINE, client_id: @authorize_form.client_id)

      render nothing: true # TODO: should we try to redirect back with an error?
    end

    private

    def identity_needs_verification?
      @authorize_form.loa3_requested? && decorated_user.identity_not_verified?
    end

    def build_authorize_form
      user_session[:openid_auth_request] = authorization_params

      OpenidConnectAuthorizeForm.new(authorization_params)
    end

    def authorization_params
      params.permit(OpenidConnectAuthorizeForm::ATTRS)
    end

    def session_params
      user_session.delete(:openid_auth_request) || {}
    end
  end
end
