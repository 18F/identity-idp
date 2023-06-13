module Api
  module Internal
    class SessionsController < ApplicationController
      include CsrfTokenConcern

      prepend_before_action :skip_session_expiration
      prepend_before_action :skip_devise_hooks

      after_action :add_csrf_token_header_to_response, only: [:update]

      respond_to :json

      def show
        render json: status_response
      end

      def update
        if live?
          analytics.session_kept_alive
          update_last_request_at
        end

        render json: status_response
      end

      private

      def status_response
        { live: live?, timeout: live?.presence && timeout }
      end

      def skip_devise_hooks
        request.env['devise.skip_timeout'] = true
        request.env['devise.skip_trackable'] = true
      end

      def live?
        timeout.present? && timeout.future?
      end

      def timeout
        Time.zone.at(last_request_at + User.timeout_in) if last_request_at.present?
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
end
