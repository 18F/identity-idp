# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include VerifyProfileConcern
  include BackupCodeReminderConcern
  include LocaleHelper
  include VerifySpAttributesConcern
  include SecondMfaReminderConcern
  include TwoFactorAuthenticatableMethods
  include AbTestingConcern

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::Redirecting::UnsafeRedirectError, with: :unsafe_redirect_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_auth_token
  rescue_from ActionController::UnknownFormat, with: :render_not_found
  rescue_from ActionView::MissingTemplate, with: :render_not_acceptable
  [
    ActiveRecord::ConnectionTimeoutError,
    PG::ConnectionBad, # raised when a Postgres connection times out
    Rack::Timeout::RequestTimeoutException,
    Redis::BaseConnectionError,
  ].each do |error|
    rescue_from error, with: :render_timeout
  end

  helper_method :decorated_sp_session, :current_sp, :user_fully_authenticated?

  prepend_before_action :add_new_relic_trace_attributes
  prepend_before_action :session_expires_at
  prepend_before_action :set_locale
  before_action :disable_caching
  before_action :cache_issuer_in_cookie
  after_action :store_web_locale_in_session

  def session_expires_at
    return if @skip_session_expiration || @skip_session_load
    session[:session_started_at] = Time.zone.now if session[:session_started_at].nil?
    redirect_with_flash_if_timeout
  end

  # for lograge
  def append_info_to_payload(payload)
    return if Lograge.lograge_config.ignore_actions&.include?(
      "#{Lograge.controller_field(payload)}##{payload[:action]}",
    )

    payload[:user_id] = analytics_user.uuid unless @skip_session_load

    payload[:git_sha] = IdentityConfig::GIT_SHA
    if IdentityConfig::GIT_TAG.present?
      payload[:git_tag] = IdentityConfig::GIT_TAG
    else
      payload[:git_branch] = IdentityConfig::GIT_BRANCH
    end

    payload
  end

  attr_writer :analytics

  def analytics
    return @analytics if @analytics
    @analytics =
      Analytics.new(
        user: analytics_user,
        request: request,
        sp: current_sp&.issuer,
        session: session,
        ahoy: ahoy,
      )
  end

  def analytics_user
    current_user || AnonymousUser.new
  end

  def attempts_api_tracker
    @attempts_api_tracker ||= AttemptsApi::Tracker.new(
      session_id: attempts_api_session_id,
      request:,
      user: analytics_user,
      sp: current_sp,
      cookie_device_uuid: cookies[:device],
      # this only works for oidc
      sp_request_uri: decorated_sp_session.request_url_params[:redirect_uri],
      enabled_for_session: attempts_api_enabled_for_session?,
    )
  end

  def user_event_creator
    @user_event_creator ||= UserEventCreator.new(request: request, current_user: current_user)
  end
  delegate :create_user_event, :create_user_event_with_disavowal, to: :user_event_creator
  delegate :remember_device_default, to: :decorated_sp_session

  def decorated_sp_session
    @decorated_sp_session ||= ServiceProviderSessionCreator.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    ).create_session
  end

  def default_url_options
    { locale: locale_url_param, host: IdentityConfig.store.domain_name }
  end

  def sign_out(*args)
    request.cookie_jar.delete('ahoy_visit')
    super
  end

  def resolved_authn_context_result
    return @resolved_authn_context_result if defined?(@resolved_authn_context_result)

    service_provider = sp_from_sp_session
    if service_provider.nil?
      @resolved_authn_context_result = Vot::Parser::Result.no_sp_result
    else
      @resolved_authn_context_result = AuthnContextResolver.new(
        user: current_user,
        service_provider: service_provider,
        vtr: sp_session[:vtr],
        acr_values: sp_session[:acr_values],
      ).result
    end
  end

  def context
    user_session[:context] || UserSessionContext::AUTHENTICATION_CONTEXT
  end

  def current_sp
    @current_sp ||= sp_from_sp_session || sp_from_request_id
  end

  private

  def attempts_api_enabled_for_session?
    current_sp&.attempts_api_enabled? && attempts_api_session_id.present?
  end

  def attempts_api_session_id
    @attempts_api_session_id ||= decorated_sp_session.attempts_api_session_id
  end

  # These attributes show up in New Relic traces for all requests.
  # https://docs.newrelic.com/docs/agents/manage-apm-agents/agent-data/collect-custom-attributes
  def add_new_relic_trace_attributes
    ::NewRelic::Agent.add_custom_attributes(amzn_trace_id: amzn_trace_id)
  end

  def amzn_trace_id
    request.headers['X-Amzn-Trace-Id']
  end

  def disable_caching
    response.headers[Rack::CACHE_CONTROL] = 'no-store'
    response.headers['pragma'] = 'no-cache'
  end

  def cache_issuer_in_cookie
    return if @skip_session_load
    cookies[:sp_issuer] = if current_sp.nil?
                            nil
                          else
                            {
                              value: current_sp.issuer,
                              expires: IdentityConfig.store.session_timeout_in_seconds.seconds,
                            }
                          end
  end

  def redirect_with_flash_if_timeout
    return unless params[:timeout]

    if params[:timeout] == 'session'
      analytics.session_timed_out
      attempts_api_tracker.session_timeout
      flash[:info] = t(
        'notices.session_timedout',
        app_name: APP_NAME,
        minutes: IdentityConfig.store.session_timeout_in_seconds.seconds.in_minutes.to_i,
      )
    elsif current_user.blank?
      flash[:info] = t(
        'notices.session_cleared',
        minutes: IdentityConfig.store.session_timeout_in_seconds.seconds.in_minutes.to_i,
      )
    end

    begin
      redirect_to url_for(permitted_timeout_params)
    rescue ActionController::UrlGenerationError # Binary data in parameters throw on redirect
      head :bad_request
    end
  end

  def permitted_timeout_params
    params.permit(:request_id)
  end

  def sp_from_sp_session
    ServiceProvider.find_by(issuer: sp_session[:issuer]) if sp_session[:issuer].present?
  end

  def sp_from_request_id
    if service_provider_request.issuer.present?
      ServiceProvider.find_by(issuer: service_provider_request.issuer)
    end
  end

  def sp_from_request_issuer_logout
    return if action_name != 'logout'
    if saml_request&.service_provider&.identifier.present?
      ServiceProvider.find_by(issuer: saml_request.service_provider.identifier)
    end
  end

  def service_provider_request
    @service_provider_request ||= ServiceProviderRequestProxy.from_uuid(params[:request_id])
  end

  def fix_broken_personal_key_url
    flash[:info] = t('account.personal_key.needs_new')

    pii_unlocked = Pii::Cacher.new(current_user, user_session).exists_in_session?

    if pii_unlocked
      cacher = Pii::Cacher.new(current_user, user_session)
      profile = current_user.active_profile
      user_session[:personal_key] = profile.encrypt_recovery_pii(cacher.fetch(profile.id))
      profile.save!

      analytics.broken_personal_key_regenerated

      manage_personal_key_url
    else
      user_session[:needs_new_personal_key] = true

      capture_password_url
    end
  end

  def after_sign_in_path_for(_user)
    return rules_of_use_path if !current_user.accepted_rules_of_use_still_valid?
    return user_please_call_url if current_user.suspended?
    return manage_password_url if session[:redirect_to_change_password].present?
    return authentication_methods_setup_url if user_needs_sp_auth_method_setup?
    return fix_broken_personal_key_url if current_user.broken_personal_key?
    return user_session.delete(:stored_location) if user_session.key?(:stored_location)
    return setup_piv_cac_url if user_session[:add_piv_cac_after_2fa]
    return login_add_piv_cac_prompt_url if session[:needs_to_setup_piv_cac_after_sign_in].present?
    return reactivate_account_url if user_needs_to_reactivate_account?
    return login_piv_cac_recommended_path if user_recommended_for_piv_cac?
    return second_mfa_reminder_url if user_needs_second_mfa_reminder?
    return backup_code_reminder_url if user_needs_backup_code_reminder?
    return duplicate_profiles_detected_url if user_duplicate_profiles_detected?
    return sp_session_request_url_with_updated_params if sp_session.key?(:request_url)
    signed_in_url
  end

  def signed_in_url
    return idv_verify_by_mail_enter_code_url if current_user.gpo_verification_pending_profile?
    account_path
  end

  def after_mfa_setup_path
    if user_account_creation_device_profile_failed?
      return device_profiling_failed_url
    elsif needs_completion_screen_reason
      sign_up_completed_url
    elsif user_needs_to_reactivate_account?
      reactivate_account_url
    else
      session[:account_redirect_path] || after_sign_in_path_for(current_user)
    end
  end

  def user_needs_to_reactivate_account?
    return false if current_user.password_reset_profile.blank?
    return false if pending_profile_newer_than_password_reset_profile?
    resolved_authn_context_result.identity_proofing?
  end

  def user_recommended_for_piv_cac?
    current_user.piv_cac_recommended_dismissed_at.nil? && current_user.has_fed_or_mil_email? &&
      !user_already_has_piv?
  end

  def user_already_has_piv?
    MfaContext.new(current_user).piv_cac_configurations.present?
  end

  def pending_profile_newer_than_password_reset_profile?
    return false if current_user.pending_profile.blank?
    return false if current_user.password_reset_profile.blank?
    current_user.pending_profile.created_at >
      current_user.password_reset_profile.updated_at
  end

  def invalid_auth_token(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.invalid_authenticity_token(
      controller: controller_info,
      user_signed_in: user_signed_in?,
    )
    flash[:error] = t('errors.general')
    redirect_back fallback_location: new_user_session_url, allow_other_host: false
  end

  def unsafe_redirect_error(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.unsafe_redirect_error(
      controller: controller_info,
      user_signed_in: user_signed_in?,
      referer: request.referer,
    )

    flash[:error] = t('errors.general')
    redirect_to new_user_session_url
  end

  def user_fully_authenticated?
    user_signed_in? &&
      session['warden.user.user.session'] &&
      !session['warden.user.user.session'][TwoFactorAuthenticatable::NEED_AUTHENTICATION] &&
      two_factor_enabled?
  end

  def confirm_two_factor_authenticated
    authenticate_user!(force: true)

    if !two_factor_enabled?
      return prompt_to_setup_mfa
    elsif !user_fully_authenticated?
      return prompt_to_verify_mfa
    elsif service_provider_mfa_policy.user_needs_sp_auth_method_setup?
      return prompt_to_setup_mfa
    elsif service_provider_mfa_policy.user_needs_sp_auth_method_verification?
      return prompt_to_verify_sp_required_mfa
    end

    enforce_total_session_duration_timeout

    true
  end

  def enforce_total_session_duration_timeout
    return sign_out_with_timeout_error if session_total_duration_expired?
    ensure_user_session_has_created_at
  end

  def sign_out_with_timeout_error
    analytics.session_total_duration_timeout
    sign_out
    flash[:info] = t('devise.failure.timeout')
    redirect_to root_url
  end

  def ensure_user_session_has_created_at
    return if user_session.nil? || user_session[:created_at].present?
    user_session[:created_at] = Time.zone.now
  end

  def session_total_duration_expired?
    session_created_at = user_session&.dig(:created_at)
    return if session_created_at.blank?
    session_created_at = Time.zone.parse(session_created_at.to_s)
    timeout_in_minutes = IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes
    (session_created_at + timeout_in_minutes) < Time.zone.now
  end

  def prompt_to_setup_mfa
    redirect_to authentication_methods_setup_url
  end

  def prompt_to_verify_mfa
    redirect_to user_two_factor_authentication_url
  end

  def prompt_to_verify_sp_required_mfa
    redirect_to sp_required_mfa_verification_url
  end

  def sp_required_mfa_verification_url
    return login_two_factor_piv_cac_url if service_provider_mfa_policy.piv_cac_required?

    if !mobile? && TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
      login_two_factor_piv_cac_url
    elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).platform_enabled?
      login_two_factor_webauthn_url(platform: true)
    elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?
      login_two_factor_webauthn_url
    else
      login_two_factor_piv_cac_url
    end
  end

  def two_factor_enabled?
    MfaPolicy.new(current_user).two_factor_enabled?
  end

  # Prevent the session from being written back to the session store at the end of the request.
  def skip_session_commit
    request.session_options[:skip] = true
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def skip_session_load
    skip_session_commit
    @skip_session_load = true
  end

  def set_locale
    I18n.locale = LocaleChooser.new(params[:locale], request).locale
  end

  def store_web_locale_in_session
    return unless user_signed_in?

    user_session[:web_locale] = I18n.locale.to_s
  end

  def pii_requested_but_locked?
    if resolved_authn_context_result.identity_proofing? || resolved_authn_context_result.ialmax?
      current_user.identity_verified? &&
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(current_user)
  end

  def service_provider_mfa_policy
    @service_provider_mfa_policy ||= ServiceProviderMfaPolicy.new(
      user: current_user,
      auth_methods_session:,
      resolved_authn_context_result:,
    )
  end
  delegate :user_needs_sp_auth_method_setup?, to: :service_provider_mfa_policy

  def sp_session
    session.fetch(:sp, {})
  end

  # Retrieves the current service provider session hash's logged request URL, if present
  # Conditionally sets the final_auth_request service provider session attribute
  # when applicable (the original SP request is SAML)
  def sp_session_request_url_with_updated_params
    return unless sp_session[:request_url].present?
    request_url = URI(sp_session[:request_url])
    url = if request_url.path.match?('saml')
            sp_session[:final_auth_request] = true
            complete_saml_url
          else
            sp_session[:request_url]
          end

    # If the user has changed the locale, we should preserve that as well
    if url && locale_url_param && UriService.params(url)[:locale] != locale_url_param
      UriService.add_params(url, locale: locale_url_param)
    else
      url
    end
  end

  def render_not_found
    respond_to do |format|
      format.json do
        render json: { error: "The page you were looking for doesn't exist" }, status: :not_found
      end
      format.any do
        render template: 'pages/page_not_found', layout: false, status: :not_found, formats: :html
      end
    end
  end

  def render_not_acceptable
    render template: 'pages/not_acceptable', layout: false, status: :not_acceptable, formats: :html
  end

  def render_bad_request
    render template: 'pages/bad_request', layout: false, status: :bad_request, formats: :html
  end

  def render_timeout(exception)
    analytics.response_timed_out(**analytics_exception_info(exception))
    if exception.instance_of?(Rack::Timeout::RequestTimeoutException)
      NewRelic::Agent.notice_error(exception)
    end
    render template: 'pages/page_took_too_long',
           layout: false, status: :service_unavailable, formats: :html
  end

  def render_full_width(template, **opts)
    render template, **opts, layout: 'application'
  end

  def analytics_exception_info(exception)
    {
      backtrace: Rails.backtrace_cleaner.send(:filter, exception.backtrace),
      exception_message: exception.to_s,
      exception_class: exception.class.name,
    }
  end

  def mobile?
    BrowserCache.parse(request.user_agent).mobile?
  end

  def user_is_banned?
    return false unless user_signed_in?
    BannedUserResolver.new(current_user).banned_for_sp?(issuer: current_sp&.issuer)
  end

  def user_account_creation_device_profile_failed?
    return false unless IdentityConfig.store.account_creation_device_profiling == :enabled
    profiling_result = find_device_profiling_result(
      DeviceProfilingResult::PROFILING_TYPES[:account_creation],
    )
    profiling_result&.rejected?
  end

  def find_device_profiling_result(type)
    DeviceProfilingResult.for_user(
      user_id: current_user.id,
      type: type,
    ).last
  end

  def user_duplicate_profiles_detected?
    return false unless sp_eligible_for_one_account?
    profile = current_user&.active_profile
    DuplicateProfileConfirmation.where(
      profile_id: profile&.id,
      confirmed_all: nil,
    ).present?
  end

  def sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp_from_sp_session&.issuer)
  end

  def handle_banned_user
    return unless user_is_banned?
    analytics.banned_user_redirect
    sign_out
    redirect_to banned_user_url
  end
end
