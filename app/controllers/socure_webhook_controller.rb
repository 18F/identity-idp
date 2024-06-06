# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :verify_authenticity_token

  def create
    # form = SecurityEventForm.new(body: request.body.read)
    # result = form.submit

    # analytics.security_event_received(**result.to_h)

    # if result.success?
      head :ok
    # else
    #   render status: :bad_request,
    #           json: {
    #             err: form.error_code,
    #             description: form.description,
    #           }
    # end
  end
end
