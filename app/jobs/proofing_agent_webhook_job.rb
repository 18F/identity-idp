# frozen_string_literal: true

class ProofingAgentWebhookJob < ApplicationJob
  queue_as :high_proofing_agent

  def perform(success:, reason:, transaction_id:, correlation_id:, analytics_attributes:)
    ProofingAgent::WebhookCaller.new(
      success:,
      reason:,
      transaction_id:,
      correlation_id:,
      analytics_attributes:,
    ).call
  end
end
