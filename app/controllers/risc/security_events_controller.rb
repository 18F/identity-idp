module Risc
  # Controller to receive SET (Security Event Tokens)
  class SecurityEventsController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      form = SecurityEventForm.new(body: request.body.read)
      result = form.submit

      analytics.track_event(Analytics::SECURITY_EVENT_RECEIVED, result.to_h)

      if result.success?
        if form.event_type == SecurityEvent::AUTHORIZATION_FRAUD_DETECTED
          ResetUserPassword.new(user: form.user).call
        end

        head :accepted
      else
        render status: :bad_request,
               json: {
                 err: form.error_code,
                 description: form.description,
               }
      end
    end
  end
end
