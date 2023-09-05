require 'rails_helper'

RSpec.describe FraudRejectionDailyJob do
  subject(:job) { FraudRejectionDailyJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(job).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    it 'rejects profiles which have been review pending for more than 30 days' do
      freeze_time do
        create(:profile, :fraud_review_pending, fraud_review_pending_at: 31.days.ago)
        create(:profile, :fraud_review_pending)

        rejected_profiles = Profile.fraud_rejection

        expect { job.perform(Time.zone.today) }.to change { rejected_profiles.count }.by(1)
        expect(job_analytics).to have_logged_event(
          'Fraud: Automatic Fraud Rejection',
          fraud_rejection_at: rejected_profiles.first.fraud_rejection_at,
        )
      end
    end
  end
end
