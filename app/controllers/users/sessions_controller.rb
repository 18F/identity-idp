module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    prepend_before_action :skip_timeout, only: [:active]
    skip_before_action :session_expires_at, only: [:active]

    def skip_timeout
      request.env['devise.skip_trackable'] = true
    end

    def create
      logger.info '[Authentication Attempt]'
      super
    end

    def active
      response.headers['Etag'] = '' # clear etags to prevent caching
      render json: { live: current_user.present?, timeout: session[:session_expires_at] }
    end

    def timeout
      flash[:notice] = t(
        'upaya.session_timedout',
        session_timeout: distance_of_time_in_words(Devise.timeout_in)
      )
      redirect_to root_url
    end
  end
end
