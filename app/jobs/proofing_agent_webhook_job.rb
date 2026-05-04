# frozen_string_literal: true

class ProofingAgentWebhookJob < ApplicationJob
  queue_as :high_proofing_agent

  def perform(success:, reason:, transaction_id:, correlation_id:)
    ProofingAgent::WebhookCaller.new(
      success:,
      reason:,
      transaction_id:,
      correlation_id:,
    ).call
  end
end
