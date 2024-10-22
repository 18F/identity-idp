# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  include RenderConditionConcern

  skip_before_action :verify_authenticity_token
  check_or_render_not_found -> { IdentityConfig.store.socure_enabled }
  before_action :check_token
  before_action :check_socure_event
  # before_action :check_doc_capture_session

  def create
    log_webhook_receipt
    fetch_results if socure_params[:event][:eventType] == 'DOCUMENTS_UPLOADED'
    render json: { message: 'Secret token is valid.' }
  end

  private

  def fetch_results
    dcs_uuid = socure_params[:event][:customer_user_id]
    dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
    SocureDocvResultsJob.perform_later(
      document_capture_session_uuid: dcs.uuid,
      service_provider_issuer: dcs.issuer,
      user_uuid: dcs.user.uuid,
    )
  end

  def check_token
    puts "\ncheck_token: #{token_valid?}\n"
    if !token_valid?
      render status: :unauthorized, json: { message: 'Invalid secret token.' }
    end
  end

  def check_socure_event
    puts "\ncheck_socure_event: #{socure_params[:event]}\n"
    if socure_params[:event].blank?
      byebug
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
