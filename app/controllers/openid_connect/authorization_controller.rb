module OpenidConnect
  class AuthorizationController < ApplicationController
    include AccountRecoverable
    include FullyAuthenticatable
    include RememberDeviceConcern
    include VerifyProfileConcern
    include VerifySPAttributesConcern

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :validate_authorize_form, only: [:index]
    before_action :force_login_if_prompt_param_is_login_and_request_is_external, only: [:index]
    before_action :store_request, only: [:index]
    before_action :apply_secure_headers_override, only: [:index]
    before_action :confirm_user_is_authenticated_with_fresh_mfa, only: :index

    #todo clara account recovery here should be handled by a before_action
    def index
      link_identity_to_service_provider
      return redirect_to account_recovery_setup_url if piv_cac_enabled_but_not_multiple_mfa_enabled?
      return redirect_to_account_or_verify_profile_url if profile_or_identity_needs_verification?
      return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
      handle_successful_handoff
    end

    private

    def confirm_user_is_authenticated_with_fresh_mfa
      return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
      redirect_to user_two_factor_authentication_url if remember_device_expired_for_sp?
    end

    def link_identity_to_service_provider
      @authorize_form.link_identity_to_service_provider(current_user, session.id)
    end

    def handle_successful_handoff
      redirect_to @authorize_form.success_redirect_uri
      delete_branded_experience
    end

    def redirect_to_account_or_verify_profile_url
      return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
      redirect_to(idv_url) if identity_needs_verification?
    end

    def profile_or_identity_needs_verification?
      return false unless @authorize_form.loa3_requested?
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
        form_action: ["'self'", authorization_params[:redirect_uri]].compact,
        preserve_schemes: true,
      )
    end

    def identity_needs_verification?
      @authorize_form.loa3_requested? && current_user.decorate.identity_not_verified?
    end

    def build_authorize_form_from_params
      @authorize_form = OpenidConnectAuthorizeForm.new(authorization_params)
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
      ServiceProviderRequestHandler.new(
        url: request.original_url,
        session: session,
        protocol_request: @authorize_form,
        protocol: FederatedProtocols::Oidc,
      ).call
    end
  end
end
