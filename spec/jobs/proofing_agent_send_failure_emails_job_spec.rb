# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentSendFailureEmailsJob, type: :job do
  subject { described_class.new }

  let(:failure_email_user_set_key) { Idv::ProofingAgent::FailureEmailUserSet::KEY }

  before do
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_send_failure_email_after_min)
      .and_return(0)
    stub_analytics
  end

  describe '#perform' do
    let(:users) do
      create_list(:user, 3, :with_proofing_agent_session)
    end
    let(:user_uuids) { users.pluck(:uuid) }
    let(:doc_capture_session) { instance_double(DocumentCaptureSession) }
    let(:proofing_results) do
      {
        reason: 'I AM ERROR',
        proofing_agent_id: Faker::Internet.uuid,
        proofing_location_id: Faker::Internet.uuid,
        correlation_id: Faker::Internet.uuid,
      }
    end
    let(:failure_email_user_set) { instance_double(Idv::ProofingAgent::FailureEmailUserSet) }
    let(:failure_email_sender) { instance_double(ProofingAgent::FailureEmailSender) }

    before do
      allow(Analytics).to receive(:new).and_return(@analytics)
      allow(failure_email_sender).to receive(:call)
      allow(ProofingAgent::FailureEmailSender).to receive(:new).and_return(failure_email_sender)
      allow(Idv::ProofingAgent::FailureEmailUserSet).to receive(:new).and_return(
        failure_email_user_set,
      )
      allow(failure_email_user_set).to receive(:remove_uuids)
    end

    context 'when a failure email users exist' do
      before do
        users.each do |user|
          allow(EncryptedRedisStructStorage).to receive(:load).with(
            user.current_proofing_agent_session.result_id,
            type: Idv::ProofingAgent::AgentProofedUser,
          ).and_return(Idv::ProofingAgent::AgentProofedUser.new(
            id: SecureRandom.uuid,
            transaction_id: user.current_proofing_agent_session.result_id,
            **proofing_results,
          ))
        end

        allow(failure_email_user_set).to receive(:find_by_time_range).and_return(user_uuids)
      end

      context 'when no processing errors occur' do
        before do
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
          expect(failure_email_user_set).to have_received(:remove_uuids).with(user_uuids)
        end

        it 'logs the job completed event' do
          expect(@analytics).to have_logged_event(
            :proofing_agent_failure_email_job_completed,
            processed_count: users.count,
            duration_sec: instance_of(Float),
          )
        end
      end

      context 'when there a processing error' do
        before do
          @raise_exception = true
          allow(failure_email_sender).to receive(:call) do
            if @raise_exception
              @raise_exception = false
              raise 'I AM ERROR'
            else
              true
            end
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
          expect(failure_email_user_set).to have_received(:remove_uuids).with(
            [users[1].uuid, users[2].uuid],
          )
        end

        it 'logs the job completed event' do
          expect(@analytics).to have_logged_event(
            :proofing_agent_failure_email_job_completed,
            processed_count: users.count - 1,
            duration_sec: instance_of(Float),
          )
        end
      end
    end

    context 'when failure email users do not exist' do
      before do
        allow(failure_email_user_set).to receive(:find_by_time_range).and_return([])
        subject.perform(Time.zone.now)
      end

      it 'does not attempt to send a failure email' do
        expect(failure_email_sender).to_not have_received(:call)
      end

      it 'removes the users with the emails sent from the failure email user set' do
        expect(failure_email_user_set).to have_received(:remove_uuids).with([])
      end

      it 'logs the job completed event' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_failure_email_job_completed,
          processed_count: 0,
          duration_sec: instance_of(Float),
        )
      end
    end
  end
end
