# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  include RenderConditionConcern

  skip_before_action :verify_authenticity_token
  check_or_render_not_found -> { IdentityConfig.store.socure_webhook_enabled }
  before_action :check_token
  before_action :check_socure_event

  def create
    log_webhook_receipt
    render json: { message: 'Secret token is valid.' }
  end

  private

  def check_token
    if !token_valid?
      render status: :unauthorized, json: { message: 'Invalid secret token.' }
    end
  end

  def check_socure_event
    if socure_params[:event].blank?
      render status: :bad_request, json: { message: 'Invalid event.' }
    end
  end

  def token_valid?
    authorization_header = request.headers['Authorization']&.split&.last

    authorization_header.present? &&
      (verify_current_key(authorization_header: authorization_header) ||
        verify_queue(authorization_header: authorization_header))
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
