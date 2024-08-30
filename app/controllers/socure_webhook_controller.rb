# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  include RenderConditionConcern

  skip_before_action :verify_authenticity_token

  check_or_render_not_found -> { IdentityConfig.store.socure_webhook_enabled }

  def create
    unless token_valid?
      return render(status: :unauthorized, json: { message: 'Invalid secret token.' })
    end
    if socure_params[:event].blank?
      return render(status: :bad_request, json: { message: 'Invalid event.' })
    end

    log_webhook_receipt
    render json: { message: 'Secret token is valid.' }
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
    return if event.blank?

    analytics.idv_doc_auth_socure_webhook_received(
      created_at: event[:created],
      customer_user_id: event[:customerUserId],
      event_type: event[:eventType],
      reference_id: event[:referenceId],
      user_id: event[:customerUserId],
    )
  end

  def socure_params
    params.permit(event: [:created, :customerUserId, :eventType, :referenceId])
  end
end
