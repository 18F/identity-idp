module OpenidConnect
  class AuthorizationController < ApplicationController
    include FullyAuthenticatable
    include RememberDeviceConcern
    include VerifyProfileConcern
    include SecureHeadersConcern
    include AuthorizationCountConcern

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :validate_authorize_form, only: [:index]
    before_action :sign_out_if_prompt_param_is_login_and_user_is_signed_in, only: [:index]
    before_action :store_request, only: [:index]
    before_action :check_sp_active, only: [:index]
    before_action :override_csp_with_uris, only: [:index]
    before_action :confirm_user_is_authenticated_with_fresh_mfa, only: :index
    before_action :prompt_for_password_if_ial2_request_and_pii_locked, only: [:index]
    before_action :bump_auth_count, only: [:index]

    def index
      return redirect_to_account_or_verify_profile_url if profile_or_identity_needs_verification?
      return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
      link_identity_to_service_provider
      return redirect_to(user_authorization_confirmation_url) if auth_count == 1
      handle_successful_handoff
    end

    private

    def check_sp_active
      return if @authorize_form.service_provider&.active?
      redirect_to sp_inactive_error_url
    end

    def check_sp_handoff_bounced
      return unless SpHandoffBounce::IsBounced.call(sp_session)
      analytics.track_event(Analytics::SP_HANDOFF_BOUNCED_DETECTED)
      redirect_to bounced_url
      true
    end

    def confirm_user_is_authenticated_with_fresh_mfa
      bump_auth_count unless user_fully_authenticated?
      return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated? &&
                                                                 service_provider_mfa_policy.
                                                                 auth_method_confirms_to_sp_request?
      redirect_to user_two_factor_authentication_url if device_not_remembered?
    end

    def device_not_remembered?
      remember_device_expired_for_sp?
    end

    def link_identity_to_service_provider
      @authorize_form.link_identity_to_service_provider(current_user, session.id)
    end

    def handle_successful_handoff
      track_events
      SpHandoffBounce::AddHandoffTimeToSession.call(sp_session)
      redirect_to @authorize_form.success_redirect_uri
      delete_branded_experience
    end

    def redirect_to_account_or_verify_profile_url
      return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
      redirect_to(idv_url) if identity_needs_verification?
    end

    def profile_or_identity_needs_verification?
      return false unless @authorize_form.ial2_or_greater?
      profile_needs_verification? || identity_needs_verification?
    end

    def track_authorize_analytics(result)
      analytics_attributes = result.to_h.except(:redirect_uri).
                             merge(user_fully_authenticated: user_fully_authenticated?)

      analytics.track_event(
        Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION, analytics_attributes
      )
    end

    def identity_needs_verification?
      ((@authorize_form.ial2_requested? || @authorize_form.ial2_strict_requested?) &&
        (current_user.decorate.identity_not_verified? ||
        decorated_session.requested_more_recent_verification?)) ||
        (@authorize_form.ial2_strict_requested? &&
        !current_user.active_profile&.includes_liveness_check?)
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

    def sign_out_if_prompt_param_is_login_and_user_is_signed_in
      return unless user_signed_in? && @authorize_form.prompt == 'login'
      return if check_sp_handoff_bounced
      sign_out unless sp_session[:request_url] == request.original_url
    end

    def prompt_for_password_if_ial2_request_and_pii_locked
      return unless pii_requested_but_locked?
      redirect_to capture_password_url
    end

    def store_request
      ServiceProviderRequestHandler.new(
        url: request.original_url,
        session: session,
        protocol_request: @authorize_form,
        protocol: FederatedProtocols::Oidc,
      ).call
    end

    def pii_requested_but_locked?
      sp_session && sp_session_ial > 1 &&
        UserDecorator.new(current_user).identity_verified? &&
        user_session[:decrypted_pii].blank?
    end

    def track_events
      analytics.track_event(Analytics::SP_REDIRECT_INITIATED, ial: sp_session_ial)
      Db::SpReturnLog.add_return(request_id, current_user.id)
      increment_monthly_auth_count
      add_sp_cost(:authentication)
    end
  end
end
