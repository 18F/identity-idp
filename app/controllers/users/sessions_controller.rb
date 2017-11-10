module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    skip_before_action :session_expires_at, only: [:active]
    skip_before_action :require_no_authentication, only: [:new]
    before_action :confirm_two_factor_authenticated, only: [:update]
    before_action :check_user_needs_redirect, only: [:new]

    def new
      analytics.track_event(Analytics::SIGN_IN_PAGE_VISIT)
      super
    end

    def create
      track_authentication_attempt(params[:user][:email])

      return process_locked_out_user if current_user && user_locked_out?(current_user)

      super
      cache_active_profile
      store_sp_metadata_in_session unless request_id.empty?
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      session[:pinged_at] = now
      Rails.logger.debug(alive?: alive?, expires_at: expires_at)
      render json: { live: alive?, timeout: expires_at }
    end

    def timeout
      analytics.track_event(Analytics::SESSION_TIMED_OUT)
      sign_out
      flash[:notice] = t(
        'session_timedout',
        app: APP_NAME,
        minutes: Figaro.env.session_timeout_in_minutes
      )
      redirect_to root_url
    end

    private

    def check_user_needs_redirect
      if user_fully_authenticated?
        redirect_to signed_in_url
      elsif current_user
        sign_out
      end
    end

    def process_locked_out_user
      decorator = current_user.decorate
      sign_out
      render(
        'two_factor_authentication/shared/max_login_attempts_reached',
        locals: { type: 'generic', decorator: decorator }
      )
    end

    def now
      @_now ||= Time.zone.now
    end

    def expires_at
      @_expires_at ||= (session[:session_expires_at]&.to_datetime || (now - 1))
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
      }

      analytics.track_event(Analytics::EMAIL_AND_PASSWORD_AUTH, properties)
    end

    def cache_active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      profile = current_user.decorate.active_or_pending_profile
      begin
        cacher.save(current_user.user_access_key, profile)
      rescue Pii::EncryptionError => err
        profile.deactivate(:encryption_error)
        analytics.track_event(Analytics::PROFILE_ENCRYPTION_INVALID, error: err.message)
      end
    end

    def user_signed_in_and_not_locked_out?(user)
      return false unless current_user
      !user_locked_out?(user)
    end

    def user_locked_out?(user)
      UserDecorator.new(user).locked_out?
    end

    def store_sp_metadata_in_session
      return if sp_session[:issuer]
      StoreSpMetadataInSession.new(session: session, request_id: request_id).call
    end

    def request_id
      params[:user].fetch(:request_id, '')
    end
  end
end
