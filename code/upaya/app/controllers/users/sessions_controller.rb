module Users
  class SessionsController < Devise::SessionsController
    include ::ActionView::Helpers::DateHelper

    before_action :halt_privileged, only: :create
    prepend_before_action :skip_timeout, only: [:active]
    skip_before_action :session_expires_at, only: [:active]

    def skip_timeout
      request.env['devise.skip_trackable'] = true
    end

    def create
      logger.info '[Authentication Attempt]'
      super
      session[:forced_idv_sign_out] = current_user.ial_token
    end

    def active
      response.headers['Etag'] = ''  # clear etags to prevent caching
      render json: { live: current_user.present?, timeout: session[:session_expires_at] }
    end

    def timeout
      flash[:notice] = I18n.t(
        'upaya.session_timedout',
        session_timeout: distance_of_time_in_words(Devise.timeout_in)
      )
      redirect_to root_url
    end

    private

    def halt_privileged
      return if Figaro.env.allow_privileged == 'yes'

      user = User.find_by_email(params[:user][:email])
      do_not_pass_go if user && user.privileged? &&
                        user.valid_password?(params[:user][:password])
    end

    def do_not_pass_go
      flash[:error] = 'You are not authorized'
      redirect_to root_url and return
    end
  end
end
