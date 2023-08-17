require 'rails_helper'

RSpec.describe GpoReminderJob do
  let(:wait_before_sending_reminder) { 14.days }

  describe '#perform' do
    subject(:perform) { job.perform(wait_before_sending_reminder.ago) }

    let(:job) { GpoReminderJob.new }
    let(:user) { create(:user, :with_pending_gpo_profile) }
    let(:pending_profile) { user.pending_profile }
    let(:job_analytics) { FakeAnalytics.new }

    before do
      pending_profile.update(
        gpo_verification_pending_at: wait_before_sending_reminder.ago,
      )
      allow(Analytics).to receive(:new).and_return(job_analytics)
    end

    it 'sends reminder emails' do
      expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'IdV: gpo reminder email sent',
      )
    end
  end
end
