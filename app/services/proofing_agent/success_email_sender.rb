# frozen_string_literal: true

module ProofingAgent
  class SuccessEmailSender
    attr_reader :user, :analytics

    def initialize(user:, analytics:)
      @user = user
      @analytics = analytics
    end

    def call(
      verified_at:,
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      transaction_id:
    )
      expiration_date = Idv::ProofingAgent::AgentProofingSucceededPresenter
        .deadline_for(verified_at: verified_at)

      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address)
          .agent_proofing_succeeded(verified_at: verified_at)
          .deliver_now_or_later
      end

      analytics.idv_proofing_agent_profile_confirmation_email_sent(
        user_id: user.uuid,
        proofing_agent: {
          correlation_id: correlation_id,
          transaction_id: transaction_id,
          agent_id: proofing_agent_id,
          location_id: proofing_location_id,
        },
        expiration_date: expiration_date,
      )
    end
  end
end
