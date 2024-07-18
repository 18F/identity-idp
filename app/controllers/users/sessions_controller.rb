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

    rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_to_signin

    skip_before_action :require_no_authentication, only: [:new]
    before_action :store_sp_metadata_in_session, only: [:new]
    before_action :check_user_needs_redirect, only: [:new]
    before_action :apply_secure_headers_override, only: [:new, :create]
    before_action :clear_session_bad_password_count_if_window_expired, only: [:create]

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
      return process_locked_out_session if session_bad_password_count_max_exceeded?
      return process_locked_out_user if current_user && user_locked_out?(current_user)
      return process_failed_captcha if !valid_captcha_result?

      rate_limit_password_failure = true
      self.resource = warden.authenticate!(auth_options)
      handle_valid_authentication
    ensure
      increment_session_bad_password_count if rate_limit_password_failure && !current_user
      track_authentication_attempt(auth_params[:email])
    end

    def destroy
      if request.method == 'GET' && IdentityConfig.store.disable_logout_get_request
        redirect_to root_path
      else
        analytics.logout_initiated(sp_initiated: false, oidc: false)
        super
      end
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

    def process_locked_out_session
      warden.logout(:user)
      warden.lock!

      flash[:error] = t(
        'errors.sign_in.bad_password_limit',
        time_left: locked_out_time_remaining,
      )
      redirect_to root_url
    end

    def locked_out_time_remaining
      locked_at = session[:max_bad_passwords_at]
      window = IdentityConfig.store.max_bad_passwords_window_in_seconds.seconds
      time_lockout_expires = Time.zone.at(locked_at) + window
      distance_of_time_in_words(Time.zone.now, time_lockout_expires, true)
    end

    def valid_captcha_result?
      return @valid_captcha_result if defined?(@valid_captcha_result)
      @valid_captcha_result = SignInRecaptchaForm.new(**recaptcha_form_args).submit(
        email: auth_params[:email],
        recaptcha_token: params.require(:user)[:recaptcha_token],
        device_cookie: cookies[:device],
      ).success?
    end

    def process_failed_captcha
      flash[:error] = t('errors.messages.invalid_recaptcha_token')
      warden.logout(:user)
      warden.lock!
      redirect_to root_url
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

    def auth_params
      params.require(:user).permit(:email, :password)
    end

    def process_locked_out_user
      presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
        'generic_login_attempts',
        current_user,
      )
      sign_out
      render_full_width('two_factor_authentication/_locked', locals: { presenter: presenter })
    end

    def handle_valid_authentication
      sign_in(resource_name, resource)
      cache_profiles(auth_params[:password])
      set_new_device_session(nil)
      event, = create_user_event(:sign_in_before_2fa)
      UserAlerts::AlertUserAboutNewDevice.schedule_alert(event:) if new_device?
      EmailAddress.update_last_sign_in_at_on_user_id_and_email(
        user_id: current_user.id,
        email: auth_params[:email],
      )
      check_password_compromised
      user_session[:platform_authenticator_available] =
        params[:platform_authenticator_available] == 'true'
      redirect_to next_url_after_valid_authentication
    end

    def track_authentication_attempt(email)
      user = User.find_with_email(email) || AnonymousUser.new

      success = current_user.present? && !user_locked_out?(user) && valid_captcha_result?
      analytics.email_and_password_auth(
        success: success,
        user_id: user.uuid,
        user_locked_out: user_locked_out?(user),
        valid_captcha_result: valid_captcha_result?,
        bad_password_count: session[:bad_password_count].to_i,
        sp_request_url_present: sp_session[:request_url].present?,
        remember_device: remember_device_cookie.present?,
        new_device: success ? new_device? : nil,
      )
    end

    def user_locked_out?(user)
      user.locked_out?
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
      AccountReset::FindPendingRequestForUser.new(
        current_user,
      ).call
    end

    def override_csp_for_google_analytics
      return unless IdentityConfig.store.participate_in_dap
      policy = current_content_security_policy
      policy.script_src(
        *policy.script_src,
        'dap.digitalgov.gov',
        'www.google-analytics.com',
        '*.googletagmanager.com',
      )
      policy.connect_src(
        *policy.connect_src,
        '*.google-analytics.com',
        '*.analytics.google.com',
        '*.googletagmanager.com',
      )
      policy.img_src(
        *policy.img_src,
        '*.google-analytics.com',
        '*.googletagmanager.com',
      )
      request.content_security_policy = policy
    end

    def sign_in_params
      params[resource_name]&.permit(:email) if request.post?
    end

    def check_password_compromised
      return if current_user.password_compromised_checked_at.present? ||
                !eligible_for_password_lookup?

      session[:redirect_to_password_compromised] =
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
