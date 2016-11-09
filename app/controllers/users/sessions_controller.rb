module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    skip_before_action :session_expires_at, only: [:active]
    skip_after_action :track_get_requests, only: [:active]
    before_action :confirm_two_factor_authenticated, only: [:update]
    prepend_before_action :check_concurrent_sessions, only: [:create]

    after_action :cache_active_profile, only: [:create]
    after_action :track_user_session, only: [:create]

    def create
      track_authentication_attempt
      super
      preserve_session_id
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      session[:pinged_at] = now
      Session.where(session_id: session.id).update_all(updated_at: now)
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

    def preserve_session_id
      # IMPORTANT session.id does not change after login.
      # see https://github.com/plataformatec/devise/issues/3706
      session_opts = session.options
      session_opts[:id] = session_store.generate_sid
      session_opts[:renew] = false
    end

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

    def existing_user
      @_existing_user ||= User.find_by(email: params[:user][:email].downcase) || AnonymousUser.new
    end

    def track_authentication_attempt
      properties = {
        success?: current_user.present?, user_id: existing_user.uuid
      }

      analytics.track_event(Analytics::EMAIL_AND_PASSWORD_AUTH, properties)
    end

    def check_concurrent_sessions
      return unless existing_user.is_a? User
      return unless existing_user.decorate.too_many_sessions?

      flash[:error] = t('errors.messages.concurrent_sessions')
      redirect_to root_url
    end

    def cache_active_profile
      cacher = Pii::Cacher.new(current_user, user_session)
      cacher.save(params[:user][:password])
    end

    def track_user_session
      session_syncer.clean(current_user)
      IdentityLinker.new(current_user, Identity::LOCAL, session.id).link_identity
    end

    def session_syncer
      SessionSyncer.new(session_store)
    end

    def session_store
      session.instance_variable_get('@by')
    end
  end
end
