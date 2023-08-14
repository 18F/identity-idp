require 'rails_helper'

RSpec.describe GpoReminderJob do
  WAIT_BEFORE_SENDING_REMINDER = 14.days

  describe '#perform' do
    subject(:perform) { job.perform(Time.zone.now - WAIT_BEFORE_SENDING_REMINDER) }

    let(:job) { GpoReminderJob.new }
    let(:user) { create(:user, :with_pending_gpo_profile) }
    let(:pending_profile) { user.pending_profile }
    let(:job_analytics) { FakeAnalytics.new }

    before do
      pending_profile.update(
        gpo_verification_pending_at: Time.zone.now - WAIT_BEFORE_SENDING_REMINDER,
      )
      allow(job).to receive(:analytics).and_return(job_analytics)
    end

    it 'sends reminder emails' do
      expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'IdV: gpo reminder email sent',
      )
    end
  end
end
