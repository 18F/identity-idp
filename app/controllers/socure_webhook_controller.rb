# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  include RenderConditionConcern

  skip_before_action :verify_authenticity_token

  check_or_render_not_found -> { IdentityConfig.store.socure_webhook_enabled }

  def create
    if token_valid?
      log_webhook_receipt
      render json: { message: 'Secret token is valid.' }
    else
      render status: :unauthorized, json: { message: 'Invalid secret token.' }
    end
  end

  private

  def token_valid?
    authorization_header = request.headers['Authorization']&.split&.last

    return false if authorization_header.nil?

    verify_current_key(authorization_header: authorization_header) ||
      verify_queue(authorization_header: authorization_header)
  end

  def verify_current_key(authorization_header:)
    ActiveSupport::SecurityUtils.secure_compare(
      authorization_header,
      IdentityConfig.store.socure_webhook_secret_key,
    )
  end

  def verify_queue(authorization_header:)
    IdentityConfig.store.socure_webhook_secret_key_queue.any? do |key|
      ActiveSupport::SecurityUtils.secure_compare(
        authorization_header,
        key,
      )
    end
  end

  def log_webhook_receipt
    event = socure_params[:event]
    analytics.idv_doc_auth_socure_webhook_received(
      event_type: event[:eventType],
      reference_id: event[:referenceId],
    )
  end

  def socure_params
    params.permit(event: [:eventType, :referenceId])
  end
end
