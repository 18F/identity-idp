# frozen_string_literal: true

module ProofingAgent
  class FailureEmailSender
    def initialize(user:, analytics:)
      @user = user
      @analytics = analytics
    end

    def call(
      visited_at:,
      reason:,
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      transaction_id: nil
    )
      return if visited_at.blank?

      @user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: @user, email_address: email_address)
          .agent_proofing_failure(visited_at: visited_at).deliver_now_or_later
      end

      @analytics.idv_proofing_agent_failure_to_proof_email_sent(
        user_id: @user.uuid,
        proofing_agent: {
          correlation_id: correlation_id,
          transaction_id: transaction_id,
          agent_id: proofing_agent_id,
          location_id: proofing_location_id,
        },
        reason: reason,
      )
    end
  end
end
