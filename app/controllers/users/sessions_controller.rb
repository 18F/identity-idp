module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    prepend_before_action :skip_timeout, only: [:active]
    skip_before_action :session_expires_at, only: [:active]

    def skip_timeout
      request.env['devise.skip_trackable'] = true
    end

    def new
      super
    end

    def create
      track_authentication_attempt(params[:user][:email])
      super
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      render json: { live: current_user.present?, timeout: session[:session_expires_at] }
    end

    def timeout
      analytics.track_anonymous_event('Session Timed Out')

      flash[:timeout] = t('session_timedout')
      redirect_to root_url
    end

    private

    def track_authentication_attempt(email)
      existing_user = User.find_by_email(email)

      return analytics.track_event('Authentication Attempt', existing_user) if existing_user

      analytics.track_anonymous_event('Authentication Attempt with nonexistent user')
    end
  end
end
