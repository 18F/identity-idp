module OpenidConnect
  class AuthorizationController < ApplicationController
    include FullyAuthenticatable
    include VerifyProfileConcern
    include VerifySPAttributesConcern

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :validate_authorize_form, only: [:index]
    before_action :force_login_if_prompt_param_is_login_and_request_is_external, only: [:index]
    before_action :store_request, only: [:index]
    before_action :add_sp_metadata_to_session, only: [:index]
    before_action :apply_secure_headers_override, only: [:index]

    def index
      return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
      @authorize_form.link_identity_to_service_provider(current_user, session.id)
      return redirect_to_account_or_verify_profile_url if profile_or_identity_needs_verification?
      return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
      handle_successful_handoff
    end

    private

    def handle_successful_handoff
      redirect_to @authorize_form.success_redirect_uri
      delete_branded_experience
    end

    def redirect_to_account_or_verify_profile_url
      return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
      redirect_to(verify_url) if identity_needs_verification?
    end

    def profile_or_identity_needs_verification?
      profile_needs_verification? || identity_needs_verification?
    end

    def track_authorize_analytics(result)
      analytics_attributes = result.to_h.except(:redirect_uri).
                             merge(user_fully_authenticated: user_fully_authenticated?)

      analytics.track_event(
        Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION, analytics_attributes
      )
    end

    def apply_secure_headers_override
      override_content_security_policy_directives(
        form_action: ["'self'", @authorize_form.sp_redirect_uri].compact,
        preserve_schemes: true
      )
    end

    def identity_needs_verification?
      @authorize_form.loa3_requested? && current_user.decorate.identity_not_verified?
    end

    def build_authorize_form_from_params
      user_session[:openid_auth_request] = authorization_params if user_session

      @authorize_form = OpenidConnectAuthorizeForm.new(authorization_params)

      @authorize_decorator = OpenidConnectAuthorizeDecorator.new(
        scopes: @authorize_form.scope
      )
    end

    def authorization_params
      params.permit(OpenidConnectAuthorizeForm::ATTRS)
    end

    def validate_authorize_form
      result = @authorize_form.submit
      track_authorize_analytics(result)

      return if result.success?

      if (redirect_uri = result.extra[:redirect_uri])
        redirect_to redirect_uri
      else
        render :error
      end
    end

    def force_login_if_prompt_param_is_login_and_request_is_external
      return unless user_signed_in? && @authorize_form.prompt == 'login'
      sign_out unless referring_host.to_s == Figaro.env.domain_name
    end

    def referring_host
      URI.parse(request.referer).host
    rescue URI::InvalidURIError
      nil
    end

    def store_request
      client_id = @authorize_form.client_id

      @request_id = SecureRandom.uuid
      ServiceProviderRequest.find_or_create_by(uuid: @request_id) do |sp_request|
        sp_request.issuer = client_id
        sp_request.loa = @authorize_form.acr_values.sort.max
        sp_request.url = request.original_url
        sp_request.requested_attributes = requested_attributes
      end
    end

    def add_sp_metadata_to_session
      StoreSpMetadataInSession.new(session: session, request_id: @request_id).call
    end

    def requested_attributes
      @_attributes ||= @authorize_decorator.requested_attributes
    end
  end
end
