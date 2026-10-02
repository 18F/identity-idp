# frozen_string_literal: true

module Test
  # Mock receiver for the outbound webhooks sent by the proofing agent flow
  # (see ProofingAgent::WebhookCaller). Lets developers and testers point
  # `idv_proofing_agent_config[].webhook.url` at this app in lower environments
  # so proofing agent webhooks have a live endpoint to hit and can be inspected.
  # Only mounted when test routes are enabled, and never serves in production.
  class ProofingAgentWebhookController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :render_not_found_in_production

    # Receives a webhook POST from the proofing agent flow. Always responds 200
    # so the sender records a successful delivery.
    def create
      body = parsed_body

      ProofingAgent::MockWebhookReceiver.record(
        body: body,
        authorization: request.headers['Authorization'],
        correlation_id: request.headers['X-Correlation-ID'],
        content_type: request.headers['Content-Type'],
        received_at: Time.zone.now.iso8601,
      )

      Rails.logger.info(
        {
          name: 'proofing_agent_mock_webhook_received',
          correlation_id: request.headers['X-Correlation-ID'],
          body: body,
        }.to_json,
      )

      render json: { received: true }
    end

    # Returns the webhooks received so far (most recent first) for inspection.
    def index
      render json: { webhooks: ProofingAgent::MockWebhookReceiver.webhooks }
    end

    # Clears the stored webhooks.
    def destroy
      ProofingAgent::MockWebhookReceiver.clear!
      render json: {}
    end

    private

    def parsed_body
      raw = request.body.read
      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def render_not_found_in_production
      return unless Rails.env.production?
      render_not_found
    end
  end
end
