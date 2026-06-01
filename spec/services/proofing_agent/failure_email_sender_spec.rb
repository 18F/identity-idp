require 'rails_helper'

RSpec.describe ProofingAgent::FailureEmailSender do
  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new }
  let(:sender) { described_class.new(user: user, analytics: analytics) }

  let(:visited_at) { '2026-03-18T12:00:00-04:00' }
  let(:reason) { 'id_fail' }
  let(:proofing_agent_id) { 'agent-1' }
  let(:proofing_location_id) { 'loc-1' }
  let(:correlation_id) { 'corr-1' }
  let(:transaction_id) { 'txn-1' }

  before { ActionMailer::Base.deliveries.clear }

  subject(:call) do
    sender.call(
      visited_at: visited_at,
      reason: reason,
      proofing_agent_id: proofing_agent_id,
      proofing_location_id: proofing_location_id,
      correlation_id: correlation_id,
      transaction_id: transaction_id,
    )
  end

  describe '#call' do
    it 'delivers a failure email to each confirmed email' do
      expect { call }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to)
        .to eq([user.confirmed_email_addresses.first.email])
    end

    it 'logs the failure-to-proof analytics event' do
      call

      expect(analytics).to have_logged_event(
        :idv_proofing_agent_failure_to_proof_email_sent,
        user_id: user.uuid,
        proofing_agent: {
          correlation_id: correlation_id,
          transaction_id: transaction_id,
          agent_id: proofing_agent_id,
          location_id: proofing_location_id,
        },
        reason: reason,
      )
    end

    context 'when visited_at is blank' do
      let(:visited_at) { nil }

      it 'does not deliver an email' do
        expect { call }.not_to change { ActionMailer::Base.deliveries.count }
      end

      it 'does not log the analytics event' do
        call
        expect(analytics).not_to have_logged_event(
          :idv_proofing_agent_failure_to_proof_email_sent,
        )
      end
    end

    context 'when transaction_id is not provided' do
      subject(:call) do
        sender.call(
          visited_at: visited_at,
          reason: reason,
          proofing_agent_id: proofing_agent_id,
          proofing_location_id: proofing_location_id,
          correlation_id: correlation_id,
        )
      end

      it 'logs the event with transaction_id: nil' do
        call
        expect(analytics).to have_logged_event(
          :idv_proofing_agent_failure_to_proof_email_sent,
          user_id: user.uuid,
          proofing_agent: a_hash_including(transaction_id: nil),
          reason: reason,
        )
      end
    end
  end
end
