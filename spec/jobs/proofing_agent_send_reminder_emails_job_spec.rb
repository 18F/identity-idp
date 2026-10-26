# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentSendReminderEmailsJob, type: :job do
  subject { described_class.new }

  before do
    freeze_time
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_send_reminder_email_after_hours)
      .and_return(0)
    allow(IdentityConfig.store).to receive(:agent_proofed_user_time_validity_hours)
      .and_return(72)
    stub_analytics
  end

  describe '#perform' do
    let(:users) do
      create_list(:user, 3, :with_proofing_agent_session, :fully_registered)
    end
    let(:user_uuids) { users.pluck(:uuid) }
    let(:verified_at) { Time.zone.now.to_s }
    let(:proofing_results) do
      {
        proofing_agent_id: Faker::Internet.uuid,
        proofing_location_id: Faker::Internet.uuid,
        correlation_id: Faker::Internet.uuid,
      }
    end
    let(:reminder_email_user_set) { instance_double(Idv::ProofingAgent::ReminderEmailUserSet) }
    let(:reminder_email_sender) { instance_double(ProofingAgent::ReminderEmailSender) }

    before do
      allow(Analytics).to receive(:new).and_return(@analytics)
      allow(reminder_email_sender).to receive(:call)
      allow(ProofingAgent::ReminderEmailSender).to receive(:new).and_return(reminder_email_sender)
      allow(Idv::ProofingAgent::ReminderEmailUserSet).to receive(:new).and_return(
        reminder_email_user_set,
      )
      allow(reminder_email_user_set).to receive(:remove_uuids)

      users.each do |user|
        session = user.document_capture_sessions.first
        session.update!(pending_agent_proofed_user_at: Time.zone.now)
        allow(EncryptedRedisStructStorage).to receive(:load).with(
          session.result_id,
          type: Idv::ProofingAgent::AgentProofedUser,
        ).and_return(Idv::ProofingAgent::AgentProofedUser.new(
          id: SecureRandom.uuid,
          verified_at: verified_at,
          transaction_id: session.result_id,
          **proofing_results,
        ))
      end

      allow(reminder_email_user_set).to receive(:find_by_time_range).and_return(user_uuids)
    end

    context 'when reminder email users exist and are all still awaiting binding' do
      before do
        subject.perform(Time.zone.now)
      end

      it 'sends a reminder email for each user', aggregate_failures: true do
        users.each do |user|
          result_id = user.document_capture_sessions.first.result_id
          expect(reminder_email_sender).to have_received(:call).with(
            **proofing_results,
            verified_at: verified_at,
            transaction_id: result_id,
          )
        end
      end

      it 'removes the processed users from the reminder email user set' do
        expect(reminder_email_user_set).to have_received(:remove_uuids).with(
          contain_exactly(*user_uuids),
        )
      end

      it 'logs the job completed event' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_reminder_email_job_completed,
          processed_count: users.count,
          duration_sec: instance_of(Float),
        )
      end
    end

    context 'when a user has already confirmed their account' do
      let(:confirmed_user) { users[0] }

      before do
        # A confirmed user has had their pending status cleared (see Profile#activate).
        confirmed_user.document_capture_sessions.first.update!(pending_agent_proofed_user_at: nil)
        subject.perform(Time.zone.now)
      end

      it 'does not send a reminder email to the confirmed user' do
        confirmed_result_id = confirmed_user.document_capture_sessions.first.result_id
        expect(reminder_email_sender).to_not have_received(:call).with(
          hash_including(transaction_id: confirmed_result_id),
        )
      end

      it 'still removes every processed user from the set' do
        expect(reminder_email_user_set).to have_received(:remove_uuids).with(
          contain_exactly(*user_uuids),
        )
      end

      it 'logs the job completed event counting all processed users' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_reminder_email_job_completed,
          processed_count: users.count,
          duration_sec: instance_of(Float),
        )
      end
    end

    context 'when a processing error occurs' do
      let(:failed_user) { users[0] }

      before do
        failed_result_id = failed_user.document_capture_sessions.first.result_id
        allow(reminder_email_sender).to receive(:call).and_return(true)
        allow(reminder_email_sender).to receive(:call).with(
          hash_including(transaction_id: failed_result_id),
        ).and_raise(StandardError.new('boom'))

        subject.perform(Time.zone.now)
      end

      it 'logs the error event' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_reminder_email_job_error,
          exception: 'boom',
        )
      end

      it 'does not remove the errored user from the set' do
        expect(reminder_email_user_set).to have_received(:remove_uuids).with(
          contain_exactly(users[1].uuid, users[2].uuid),
        )
      end

      it 'logs the job completed event excluding the errored user' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_reminder_email_job_completed,
          processed_count: users.count - 1,
          duration_sec: instance_of(Float),
        )
      end
    end

    context 'when reminder email users do not exist' do
      before do
        allow(reminder_email_user_set).to receive(:find_by_time_range).and_return([])
        subject.perform(Time.zone.now)
      end

      it 'does not attempt to send a reminder email' do
        expect(reminder_email_sender).to_not have_received(:call)
      end

      it 'removes an empty set of users' do
        expect(reminder_email_user_set).to have_received(:remove_uuids).with([])
      end

      it 'logs the job completed event' do
        expect(@analytics).to have_logged_event(
          :proofing_agent_reminder_email_job_completed,
          processed_count: 0,
          duration_sec: instance_of(Float),
        )
      end
    end
  end
end
