# frozen_string_literal: true

module ProofingAgent
  # In-memory store for proofing agent webhooks received by the mock endpoint
  # (Test::ProofingAgentWebhookController). Used in local development and lower
  # environments to capture and inspect outbound webhooks sent by the proofing
  # agent flow (see ProofingAgent::WebhookCaller) without a real external
  # receiver. Not for production use.
  class MockWebhookReceiver
    # Keep only the most recent webhooks so the store cannot grow unbounded.
    MAX_WEBHOOKS = 100

    Webhook = Struct.new(
      :body,
      :authorization,
      :correlation_id,
      :content_type,
      :received_at,
      keyword_init: true,
    ) do
      def as_json(*)
        {
          body: body,
          authorization: authorization,
          correlation_id: correlation_id,
          content_type: content_type,
          received_at: received_at,
        }
      end
    end

    class << self
      def record(body:, authorization:, correlation_id:, content_type:, received_at:)
        webhooks.unshift(
          Webhook.new(
            body: body,
            authorization: authorization,
            correlation_id: correlation_id,
            content_type: content_type,
            received_at: received_at,
          ),
        )
        webhooks.slice!(MAX_WEBHOOKS..) if webhooks.length > MAX_WEBHOOKS
      end

      # Most recently received webhooks first.
      def webhooks
        @webhooks ||= []
      end

      def clear!
        @webhooks = []
      end
    end
  end
end
