module Api
  class SessionsController < ApplicationController
    include CsrfTokenConcern

    prepend_before_action :skip_session_expiration
    prepend_before_action :skip_devise_hooks

    after_action :add_csrf_token_header_to_response, only: [:update]

    respond_to :json

    def show
      render json: { active: active?, timeout: timeout }
    end

    def update
      analytics.session_kept_alive if active?
      update_last_request_at
      render json: { active: active?, timeout: timeout }
    end

    def destroy
      analytics.session_timed_out
      request_id = sp_session[:request_id]
      sign_out
      render json: { redirect: root_url(request_id:, timeout: :session) }
    end

    private

    def skip_devise_hooks
      request.env['devise.skip_timeout'] = true
      request.env['devise.skip_trackable'] = true
    end

    def active?
      timeout.future?
    end

    def timeout
      if last_request_at.present?
        Time.zone.at(last_request_at + User.timeout_in)
      else
        Time.current
      end
    end

    def last_request_at
      warden_session['last_request_at'] if warden_session
    end

    def update_last_request_at
      warden_session['last_request_at'] = Time.zone.now.to_i if warden_session
    end

    def warden_session
      session['warden.user.user.session']
    end
  end
end
