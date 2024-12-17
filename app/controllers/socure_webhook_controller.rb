# frozen_string_literal: true

class SocureWebhookController < ApplicationController
  include RenderConditionConcern

  skip_before_action :verify_authenticity_token
  check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }
  before_action :check_token
  before_action :check_socure_event

  def create
    begin
      log_webhook_receipt
      repeat_webhook
      process_webhook_event
    rescue StandardError => e
      NewRelic::Agent.notice_error(e)
    ensure
      render json: { message: 'Secret token is valid.' }, status: :ok
    end
  end

  private

  def process_webhook_event
    case event[:eventType]
    when 'DOCUMENTS_UPLOADED'
      increment_rate_limiter
      fetch_results
    when 'SESSION_EXPIRED', 'SESSION_COMPLETE'
      reset_docv_url
    end
  end

  def fetch_results
    dcs = document_capture_session
    raise 'DocumentCaptureSession not found' if dcs.blank?

    if IdentityConfig.store.ruby_workers_idv_enabled
      SocureDocvResultsJob.perform_later(document_capture_session_uuid: dcs.uuid)
    else
      SocureDocvResultsJob.perform_now(document_capture_session_uuid: dcs.uuid, async: false)
    end
  end

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
      IdentityConfig.store.socure_docv_webhook_secret_key,
    )
  end

  def verify_queue(authorization_header:)
    IdentityConfig.store.socure_docv_webhook_secret_key_queue.any? do |key|
      ActiveSupport::SecurityUtils.secure_compare(
        authorization_header,
        key,
      )
    end
  end

  def log_webhook_receipt
    analytics.idv_doc_auth_socure_webhook_received(
      created_at: event[:created],
      customer_user_id: event[:customerUserId],
      docv_transaction_token:,
      event_type: event[:eventType],
      reference_id: event[:referenceId],
      user_id: user&.uuid,
    )
  end

  def increment_rate_limiter
    if document_capture_session.present?
      rate_limiter.increment!
    end
    # Logic to throw an error when no DocumentCaptureSession found will be done in ticket LG-14905
  end

  def reset_docv_url
    if document_capture_session.present?
      document_capture_session.socure_docv_capture_app_url = nil
      document_capture_session.save
    end
  end

  def document_capture_session
    @document_capture_session ||= DocumentCaptureSession.find_by(
      socure_docv_transaction_token: docv_transaction_token,
    )
  end

  def event
    @event ||= socure_params[:event]
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      user: document_capture_session.user,
      rate_limit_type: :idv_doc_auth,
    )
  end

  def socure_params
    params.permit(
      event: [:created, :customerUserId, :eventType, :referenceId,
              :docvTransactionToken, :docVTransactionToken],
    )
  end

  def user
    @user ||= document_capture_session&.user
  end

  def docv_transaction_token
    @docv_transaction_token ||= event[:docvTransactionToken] || event[:docVTransactionToken]
  end

  def repeat_webhook
    endpoints = IdentityConfig.store.socure_docv_webhook_repeat_endpoints
    return if endpoints.blank?

    headers = {
      Authorization: request.headers['Authorization'],
      'Content-Type': request.headers['Content-Type'],
    }

    body = socure_params.to_h

    endpoints.each do |endpoint|
      if IdentityConfig.store.ruby_workers_idv_enabled
        SocureDocvRepeatWebhooksJob.perform_later(body:, headers:, endpoint:)
      else
        SocureDocvRepeatWebhooksJob.perform_now(body:, headers:, endpoint:)
      end
    end
  end
end
