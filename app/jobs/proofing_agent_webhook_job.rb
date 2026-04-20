# frozen_string_literal: true

class ProofingAgentWebhookJob < ApplicationJob
  queue_as :high_proofing_agent

  def perform(webhook_url:, success:, reason:, transaction_id:)
    ProofingAgent::WebhookCaller.new(
      webhook_url:,
      success:,
      reason:,
      transaction_id:,
    ).call
  end
end
