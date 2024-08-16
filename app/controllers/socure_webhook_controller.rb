# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def on_event
    analytics.idv_socure_webhook_hit(body: request.raw_post)

    render json: { message: 'Got here.' }
  end
end
