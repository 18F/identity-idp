module Users
  class SessionsController < Devise::SessionsController # rubocop:disable Metrics/ClassLength
    include ::ActionView::Helpers::DateHelper
    include SecureHeadersConcern
    include RememberDeviceConcern
    include Ial2ProfileConcern

    rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_to_signin

    skip_before_action :session_expires_at, only: [:active]
    skip_before_action :require_no_authentication, only: [:new]
    before_action :store_sp_metadata_in_session, only: [:new]
    before_action :check_user_needs_redirect, only: [:new]
    before_action :apply_secure_headers_override, only: [:new]

    def new
      byebug
      analytics.track_event(
        Analytics::SIGN_IN_PAGE_VISIT,
        flash: flash[:alert],
        stored_location: session['user_return_to'],
      )

      @ial = sp_session ? sp_session_ial : 1
      super
    end

    def create
      track_authentication_attempt(auth_params[:email])

      return process_locked_out_user if current_user && user_locked_out?(current_user)

      self.resource = warden.authenticate!(auth_options)
      handle_valid_authentication
    end

    def destroy
      analytics.track_event(Analytics::LOGOUT_INITIATED, sp_initiated: false, oidc: false)
      super
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      session[:pinged_at] = now
      Rails.logger.debug(alive?: alive?, expires_at: expires_at)
      render json: { live: alive?, timeout: expires_at, remaining: remaining_session_time }
    end

    def timeout
      analytics.track_event(Analytics::SESSION_TIMED_OUT)
      request_id = sp_session[:request_id]
      sign_out
      flash[:notice] = t(
        'notices.session_timedout',
        app: APP_NAME,
        minutes: Figaro.env.session_timeout_in_minutes,
      )
      redirect_to root_url(request_id: request_id)
    end

    private

    def redirect_to_signin
      controller_info = 'users/sessions#create'
      analytics.track_event(Analytics::INVALID_AUTHENTICITY_TOKEN, controller: controller_info)
      sign_out
      flash[:alert] = t('errors.invalid_authenticity_token')
      redirect_back fallback_location: new_user_session_url
    end

    def check_user_needs_redirect
      if user_fully_authenticated?
        redirect_to signed_in_url
      elsif current_user
        sign_out
      end
    end

    def auth_params
      params.require(:user).permit(:email, :password, :request_id)
    end

    def process_locked_out_user
      presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
        'generic_login_attempts',
        current_user.decorate,
      )
      sign_out
      render_full_width('shared/_failure', locals: { presenter: presenter })
    end

    def handle_valid_authentication
      sign_in(resource_name, resource)
      cache_active_profile(auth_params[:password])
      add_sp_cost(:digest)
      create_user_event(:sign_in_before_2fa)
      update_last_sign_in_at_on_email
      redirect_to user_two_factor_authentication_url
    end

    def now
      @_now ||= Time.zone.now
    end

    def expires_at
      @_expires_at ||= (session[:session_expires_at]&.to_datetime || (now - 1))
    end

    def remaining_session_time
      expires_at.to_i - Time.zone.now.to_i
    end

    def alive?
      return false unless session && expires_at
      session_alive = expires_at > now
      current_user.present? && session_alive
    end

    def track_authentication_attempt(email)
      user = User.find_with_email(email) || AnonymousUser.new

      properties = {
        success: user_signed_in_and_not_locked_out?(user),
        user_id: user.uuid,
        user_locked_out: user_locked_out?(user),
        stored_location: session['user_return_to'],
        sp_request_url_present: sp_session[:request_url].present?,
        remember_device: remember_device_cookie.present?,
      }

      analytics.track_event(Analytics::EMAIL_AND_PASSWORD_AUTH, properties)
    end

    def update_last_sign_in_at_on_email
      email_address = current_user.email_addresses.find_with_email(params[:user][:email])
      email_address.update!(last_sign_in_at: Time.zone.now)
    end

    def user_signed_in_and_not_locked_out?(user)
      return false unless current_user
      !user_locked_out?(user)
    end

    def user_locked_out?(user)
      UserDecorator.new(user).locked_out?
    end

    def store_sp_metadata_in_session
      return if sp_session[:issuer] || request_id.blank?
      StoreSpMetadataInSession.new(session: session, request_id: request_id).call
    end

    def request_id
      params.fetch(:request_id, '')
    end

    def sp_session_ial
      sp_session[:ial2] ? 2 : 1
    end
  end
end
