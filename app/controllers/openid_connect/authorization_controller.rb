module OpenidConnect
  class AuthorizationController < ApplicationController
    before_action :confirm_two_factor_authenticated

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :load_authorize_form_from_session, only: [:create, :destroy]

    before_action :apply_secure_headers_override, only: [:index]

    def index
      return redirect_to verify_url if identity_needs_verification?

      success = @authorize_form.valid?
      analytics.track_event(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                            success: success,
                            client_id: @authorize_form.client_id,
                            errors: @authorize_form.errors.messages)

      return create if already_allowed?

      render(success ? :index : :error)
    end

    def create
      result = @authorize_form.submit(current_user, session.id)
      analytics.track_event(Analytics::OPENID_CONNECT_ALLOW, result.except(:redirect_uri))

      if (redirect_uri = result[:redirect_uri])
        redirect_to redirect_uri
      else
        render :error
      end
    end

    def destroy
      analytics.track_event(Analytics::OPENID_CONNECT_DECLINE, client_id: @authorize_form.client_id)

      render nothing: true # TODO: should we try to redirect back with an error?
    end

    private

    def already_allowed?
      IdentityLinker.new(current_user, @authorize_form.client_id).already_linked?
    end

    def apply_secure_headers_override
      override_content_security_policy_directives(
        form_action: ["'self'", @authorize_form.allowed_form_action].compact,
        preserve_schemes: true
      )
    end

    def identity_needs_verification?
      @authorize_form.loa3_requested? && decorated_user.identity_not_verified?
    end

    def build_authorize_form_from_params
      user_session[:openid_auth_request] = authorization_params

      @authorize_form = OpenidConnectAuthorizeForm.new(authorization_params)

      @authorize_decorator = OpenidConnectAuthorizeDecorator.new(
        scopes: @authorize_form.scope,
        service_provider: @authorize_form.service_provider
      )
    end

    def authorization_params
      params.permit(OpenidConnectAuthorizeForm::ATTRS)
    end

    def load_authorize_form_from_session
      @authorize_form = OpenidConnectAuthorizeForm.new(session_params)
    end

    def session_params
      user_session.delete(:openid_auth_request) || {}
    end
  end
end
