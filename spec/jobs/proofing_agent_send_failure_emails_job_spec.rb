# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentSendFailureEmailsJob, type: :job do
  subject { described_class.new }

  let(:failure_email_user_set_key) { Idv::ProofingAgent::FailureEmailUserSet::KEY }

  before do
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_send_failure_email_after_min)
      .and_return(0)
    REDIS_POOL.with do |client|
      client.del(Idv::ProofingAgent::FailureEmailUserSet::KEY) # empty set before each test
    end
    stub_analytics
  end

  after(:all) do
    REDIS_POOL.with do |client|
      client.del(Idv::ProofingAgent::FailureEmailUserSet::KEY) # empty set after tests are completed
    end
  end

  describe '#perform' do
    let(:users) do
      create_list(:user, 3, :with_proofing_agent_session)
    end
    let(:doc_capture_session) { instance_double(DocumentCaptureSession) }
    let(:proofing_results) do
      {
        reason: 'I AM ERROR',
        proofing_agent_id: Faker::Internet.uuid,
        proofing_location_id: Faker::Internet.uuid,
        correlation_id: Faker::Internet.uuid,
      }
    end
    let(:failure_email_users) { Idv::ProofingAgent::FailureEmailUserSet.new }
    let(:failure_email_sender) { instance_double(ProofingAgent::FailureEmailSender) }

    before do
      allow(failure_email_sender).to receive(:call)
      allow(ProofingAgent::FailureEmailSender).to receive(:new).and_return(failure_email_sender)
    end

    context 'when a failure email exists' do
      before do
        users.each do |user|
          failure_email_users.add(user.uuid)

          allow(EncryptedRedisStructStorage).to receive(:load).with(
            user.current_proofing_agent_session.result_id,
            type: Idv::ProofingAgent::AgentProofedUser,
          ).and_return(Idv::ProofingAgent::AgentProofedUser.new(
            id: SecureRandom.uuid,
            transaction_id: user.current_proofing_agent_session.result_id,
            **proofing_results,
          ))
        end

        subject.perform(Time.zone.now)
      end

      it 'sends a failure email and logs email event for each user', aggregate_failures: true do
        users.each do |user|
          expect(failure_email_sender).to have_received(:call).with(
            **proofing_results,
            visited_at: user.current_proofing_agent_session.requested_at.iso8601,
            transaction_id: user.current_proofing_agent_session.result_id,
          )
        end
      end

      it 'removes the users with the emails sent from the failure email user set' do
        expect(
          REDIS_POOL.with do |client|
            client.zrange(failure_email_user_set_key, 0, -1)
          end,
        ).to eq([])
      end
    end
  end
end
