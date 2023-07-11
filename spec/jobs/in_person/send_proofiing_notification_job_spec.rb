require 'rails_helper'

RSpec.describe InPerson::SendProofingNotificationJob do
  let(:job) { InPerson::SendProofingNotificationJob.new }
  let(:analytics) { FakeAnalytics.new }

  let!(:passed_enrollment_without_notificaiton) { create(:in_person_enrollment, :passed) }
  let!(:passed_enrollment) do
    create(:in_person_enrollment, :passed, :with_notification_phone_configuration)
  end
  let!(:failing_enrollment) do
    create(:in_person_enrollment, :failed, :with_notification_phone_configuration)
  end
  before do
    ActiveJob::Base.queue_adapter = :test
    allow(job).to receive(:analytics).and_return(analytics)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_send_proofing_notifications_enabled).
      and_return(in_person_send_proofing_notifications_enabled)
  end

  describe '#perform' do
    context 'in person proofing disabled' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_send_proofing_notifications_enabled) { true }
      it 'returns true without doing anything' do
        expect(analytics).not_to receive(
          :idv_in_person_usps_proofing_results_notification_job_started,
        )
        expect(analytics).not_to receive(
          :idv_in_person_usps_proofing_results_notification_job_completed,
        )
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        expect(job.perform(passed_enrollment)).to be(true)
      end
    end
    context 'job disabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { false }
      it 'returns true without doing anything' do
        expect(analytics).not_to receive(
          :idv_in_person_usps_proofing_results_notification_job_started,
        )
        expect(analytics).not_to receive(
          :idv_in_person_usps_proofing_results_notification_job_completed,
        )
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        expect(job.perform(passed_enrollment)).to be(true)
      end
    end
    context 'ipp and job enabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { true }
      context 'without notification phone notification' do
        it 'returns true without doing anything' do
          expect(analytics).not_to receive(
            :idv_in_person_usps_proofing_results_notification_job_started,
          )
          expect(analytics).not_to receive(
            :idv_in_person_usps_proofing_results_notification_job_completed,
          )
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_job_skipped,
          )
          expect(job.perform(passed_enrollment_without_notificaiton)).to be(true)
        end
      end
      context 'with notification phone configuration' do
        it 'send notificaiton successfully when enrollment is successful' do
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_job_started,
          )
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_job_completed,
          )
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_sent_success,
          )
          expect(job.perform(passed_enrollment)).to be(true)
        end
        it 'send notification successfully when enrollment failed' do
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_job_started,
          )
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_job_completed,
          )
          expect(analytics).to receive(
            :idv_in_person_usps_proofing_results_notification_sent_success,
          )
          expect(job.perform(failing_enrollment)).to be(true)
        end
      end
    end
  end
end
