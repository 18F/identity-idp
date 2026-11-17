# frozen_string_literal: true

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
        else
          skip_session_commit
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

      # A session is kept alive only while it still belongs to a signed-in person and is inside its
      # total duration. One whose person has signed out or been signed out, or whose total duration
      # (session_total_duration_timeout_in_minutes) has run out, is reported as not live and is not
      # written back, so its record in the session store keeps the expiry it already has instead of
      # being renewed by the request.
      def live?
        timeout.present? && timeout.future? && signed_in? && within_total_duration?
      end

      def signed_in?
        session['warden.user.user.key'].present?
      end

      def within_total_duration?
        created_at = warden_session['created_at']
        return true if created_at.blank?

        total = IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes
        Time.zone.parse(created_at.to_s) + total > Time.zone.now
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
