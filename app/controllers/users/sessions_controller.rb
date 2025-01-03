# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper
    include SecureHeadersConcern
    include RememberDeviceConcern
    include Ial2ProfileConcern
    include Api::CsrfTokenConcern
    include ForcedReauthenticationConcern
    include NewDeviceConcern
    include AbTestingConcern
    include RecaptchaConcern

    rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_to_signin

    skip_before_action :require_no_authentication, only: [:new]
    before_action :store_sp_metadata_in_session, only: [:new]
    before_action :check_user_needs_redirect, only: [:new]
    before_action :apply_secure_headers_override, only: [:new, :create]
    before_action :clear_session_bad_password_count_if_window_expired, only: [:create]
    before_action :set_analytics_user_from_params, only: :create
    before_action :allow_csp_recaptcha_src, if: :recaptcha_enabled?

    after_action :add_recaptcha_resource_hints, if: :recaptcha_enabled?

    def new
      override_csp_for_google_analytics

      @issuer_forced_reauthentication = issuer_forced_reauthentication?(
        issuer: decorated_sp_session.sp_issuer,
      )
      analytics.sign_in_page_visit(flash: flash[:alert])
      session[:sign_in_page_visited_at] = Time.zone.now.to_s
      super
    end

    def create
      session[:sign_in_flow] = :sign_in
      return process_rate_limited if session_bad_password_count_max_exceeded?
      return process_locked_out_user if current_user && user_locked_out?(current_user)
      return process_rate_limited if rate_limited?

      rate_limit_password_failure = true

      return process_failed_captcha unless recaptcha_response.success? || log_captcha_failures_only?

      self.resource = warden.authenticate!(auth_options)
      handle_valid_authentication
    ensure
      handle_invalid_authentication if rate_limit_password_failure && !current_user
      track_authentication_attempt
    end

    def destroy
      if request.method == 'GET' && IdentityConfig.store.disable_logout_get_request
        redirect_to root_path
      else
        analytics.logout_initiated(sp_initiated: false, oidc: false)
        super
      end
    end

    def analytics_user
      @analytics_user || AnonymousUser.new
    end

    private

    def clear_session_bad_password_count_if_window_expired
      locked_at = session[:max_bad_passwords_at]
      window = IdentityConfig.store.max_bad_passwords_window_in_seconds
      return if locked_at.nil? || (locked_at + window) > Time.zone.now.to_i
      [:max_bad_passwords_at, :bad_password_count].each { |x| session.delete(x) }
    end

    def session_bad_password_count_max_exceeded?
      session[:bad_password_count].to_i >= IdentityConfig.store.max_bad_passwords
    end

    def increment_session_bad_password_count
      session[:bad_password_count] = session[:bad_password_count].to_i + 1
      return unless session_bad_password_count_max_exceeded?
      session[:max_bad_passwords_at] ||= Time.zone.now.to_i
    end

    def process_rate_limited
      sign_out(:user)
      warden.lock!

      flash[:error] = t(
        'errors.sign_in.bad_password_limit',
        time_left: locked_out_time_remaining,
      )
      redirect_to root_url
    end

    def locked_out_time_remaining
      if session[:max_bad_passwords_at]
        locked_at = session[:max_bad_passwords_at]
        window = IdentityConfig.store.max_bad_passwords_window_in_seconds.seconds
        time_lockout_expires = Time.zone.at(locked_at) + window
      else
        time_lockout_expires = rate_limiter&.expires_at || Time.zone.now
      end

      distance_of_time_in_words(Time.zone.now, time_lockout_expires, true)
    end

    def recaptcha_response
      @recaptcha_response ||= recaptcha_form.submit(
        recaptcha_token: params.require(:user)[:recaptcha_token],
      )
    end

    def recaptcha_form
      @recaptcha_form ||= SignInRecaptchaForm.new(
        email: auth_params[:email],
        device_cookie: cookies[:device],
        ab_test_bucket: ab_test_bucket(:RECAPTCHA_SIGN_IN, user: user_from_params),
        **recaptcha_form_args,
      )
    end

    def recaptcha_enabled?
      FeatureManagement.sign_in_recaptcha_enabled?
    end

    def captcha_validation_performed?
      !recaptcha_form.exempt?
    end

    def process_failed_captcha
      sign_out(:user)
      warden.lock!
      redirect_to sign_in_security_check_failed_url
    end

    def recaptcha_form_args
      args = { analytics: }
      if IdentityConfig.store.recaptcha_mock_validator
        args.merge(
          form_class: RecaptchaMockForm,
          score: params.require(:user)[:recaptcha_mock_score].to_f,
        )
      elsif FeatureManagement.recaptcha_enterprise?
        args.merge(form_class: RecaptchaEnterpriseForm)
      else
        args
      end
    end

    def redirect_to_signin
      controller_info = 'users/sessions#create'
      analytics.invalid_authenticity_token(controller: controller_info)
      sign_out
      flash[:error] = t('errors.general')
      redirect_back fallback_location: new_user_session_url, allow_other_host: false
    end

    def check_user_needs_redirect
      if user_fully_authenticated?
        redirect_to signed_in_url
      elsif current_user
        redirect_to user_two_factor_authentication_url
      end
    end

    def user_from_params
      return @user_from_params if defined?(@user_from_params)
      @user_from_params = User.find_with_email(auth_params[:email])
    end

    def auth_params
      params.require(:user).permit(:email, :password)
    end

    def set_analytics_user_from_params
      @analytics_user = user_from_params
    end

    def process_locked_out_user
      presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
        'generic_login_attempts',
        current_user,
      )
      sign_out
      render_full_width('two_factor_authentication/_locked', locals: { presenter: presenter })
    end

    def handle_invalid_authentication
      rate_limiter&.increment!
      increment_session_bad_password_count
    end

    def handle_valid_authentication
      rate_limiter&.reset!
      sign_in(resource_name, resource)
      cache_profiles(auth_params[:password])
      set_new_device_session(nil)
      event, = create_user_event(:sign_in_before_2fa)
      UserAlerts::AlertUserAboutNewDevice.schedule_alert(event:) if new_device?
      EmailAddress.update_last_sign_in_at_on_user_id_and_email(
        user_id: current_user.id,
        email: auth_params[:email],
      )
      user_session[:captcha_validation_performed_at_sign_in] = captcha_validation_performed?
      user_session[:platform_authenticator_available] =
        params[:platform_authenticator_available] == 'true'
      check_password_compromised
      redirect_to next_url_after_valid_authentication
    end

    def track_authentication_attempt
      user = user_from_params || AnonymousUser.new

      success = current_user.present? &&
                !user_locked_out?(user) &&
                (recaptcha_response.success? || log_captcha_failures_only?)

      analytics.email_and_password_auth(
        **recaptcha_response,
        success: success,
        user_locked_out: user_locked_out?(user),
        rate_limited: rate_limited?,
        captcha_validation_performed: captcha_validation_performed?,
        valid_captcha_result: recaptcha_response.success?,
        bad_password_count: session[:bad_password_count].to_i,
        sp_request_url_present: sp_session[:request_url].present?,
        remember_device: remember_device_cookie.present?,
        new_device: success ? new_device? : nil,
      )
    end

    def user_locked_out?(user)
      user.locked_out?
    end

    def rate_limited?
      !!rate_limiter&.limited?
    end

    def rate_limiter
      return @rate_limiter if defined?(@rate_limiter)
      user = user_from_params
      return @rate_limiter = nil unless user
      @rate_limiter = RateLimiter.new(
        rate_limit_type: :sign_in_user_id_per_ip,
        target: [user.id, request.ip].join('-'),
      )
    end

    def store_sp_metadata_in_session
      return if sp_session[:issuer] || request_id.blank?
      StoreSpMetadataInSession.new(session: session, request_id: request_id).call
    end

    def request_id
      params.fetch(:request_id, '')
    end

    def next_url_after_valid_authentication
      if user_is_banned?
        analytics.banned_user_redirect
        sign_out
        banned_user_url
      elsif pending_account_reset_request.present?
        account_reset_pending_url
      elsif current_user.accepted_rules_of_use_still_valid?
        user_two_factor_authentication_url
      else
        rules_of_use_url
      end
    end

    def pending_account_reset_request
      AccountReset::PendingRequestForUser.new(
        current_user,
      ).get_account_reset_request
    end

    def override_csp_for_google_analytics
      return unless IdentityConfig.store.participate_in_dap
      # See: https://github.com/digital-analytics-program/gov-wide-code#content-security-policy
      policy = current_content_security_policy
      policy.script_src(
        *policy.script_src,
        'www.google-analytics.com',
        'www.googletagmanager.com',
      )
      policy.connect_src(
        *policy.connect_src,
        'www.google-analytics.com',
      )
      request.content_security_policy = policy
    end

    def sign_in_params
      params[resource_name]&.permit(:email) if request.post?
    end

    def check_password_compromised
      return if current_user.password_compromised_checked_at.present? ||
                !eligible_for_password_lookup?

      session[:redirect_to_change_password] =
        PwnedPasswords::LookupPassword.call(auth_params[:password])
      update_user_password_compromised_checked_at
    end

    def eligible_for_password_lookup?
      FeatureManagement.check_password_enabled? &&
        randomize_check_password?
    end

    def update_user_password_compromised_checked_at
      current_user.update!(password_compromised_checked_at: Time.zone.now)
    end

    def randomize_check_password?
      SecureRandom.random_number(IdentityConfig.store.compromised_password_randomizer_value) >=
        IdentityConfig.store.compromised_password_randomizer_threshold
    end

    def log_captcha_failures_only?
      IdentityConfig.store.sign_in_recaptcha_log_failures_only
    end
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
end
