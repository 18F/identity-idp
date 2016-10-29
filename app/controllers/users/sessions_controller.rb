module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    skip_before_action :session_expires_at, only: [:active]
    skip_after_action :track_get_requests, only: [:active]
    before_action :confirm_two_factor_authenticated, only: [:update]

    after_action :cache_active_profile, only: [:create]

    def create
      track_authentication_attempt(params[:user][:email])
      super
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      session[:pinged_at] = now
      Rails.logger.debug("alive?:#{alive?} expires_at:#{expires_at} now:#{now}")
      render json: { live: alive?, timeout: expires_at }
    end

    def timeout
      if sign_out
        analytics.track_event(Analytics::SESSION_TIMED_OUT)
        flash[:timeout] = t('session_timedout')
      end
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
      existing_user = User.find_by(email: email.downcase)

      if existing_user
        return analytics.track_event(Analytics::AUTHENTICATION_ATTEMPT, user_id: existing_user.uuid)
      end

      analytics.track_event(Analytics::AUTHENTICATION_ATTEMPT_NONEXISTENT)
    end

    def cache_active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      cacher.save(params[:user][:password])
    end
  end
end
