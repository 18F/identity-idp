module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    skip_before_action :session_expires_at, only: [:active]
    before_action :confirm_two_factor_authenticated, only: [:update]

    def new
      analytics.track_event(Analytics::SIGN_IN_PAGE_VISIT)
      super
    end

    def create
      track_authentication_attempt(params[:user][:email])

      if current_user && user_locked_out?(current_user)
        render 'two_factor_authentication/shared/max_login_attempts_reached'
        sign_out
        return
      end

      super
      cache_active_profile
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
      flash[:timeout] = t('session_timedout')
      redirect_to root_url
    end

    private

    def now
      @_now ||= Time.zone.now
    end

    def expires_at
      @_expires_at ||= (session[:session_expires_at] || (now - 1))
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
        user_locked_out: user_locked_out?(user)
      }

      analytics.track_event(Analytics::EMAIL_AND_PASSWORD_AUTH, properties)
    end

    def cache_active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      begin
        cacher.save(current_user.user_access_key)
      rescue Pii::EncryptionError => err
        current_user.active_profile.deactivate(:encryption_error)
        analytics.track_event(Analytics::PROFILE_ENCRYPTION_INVALID, error: err.message)
      end
    end

    def user_signed_in_and_not_locked_out?(user)
      return false unless current_user.present?

      !user_locked_out?(user)
    end

    def user_locked_out?(user)
      UserDecorator.new(user).blocked_from_entering_2fa_code?
    end
  end
end
