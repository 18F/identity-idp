require 'rails_helper'

RSpec.describe FraudRejectionDailyJob do
  subject(:job) { FraudRejectionDailyJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(job).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    it 'rejects profiles which have been review pending for more than 30 days' do
      create(:profile, fraud_review_pending: true, verified_at: 31.days.ago)
      create(:profile, fraud_review_pending: true, verified_at: 20.days.ago)

      rejected_profiles = Profile.where(fraud_rejection: true)

      expect { job.perform }.to change { rejected_profiles.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'Automatic Fraud Rejection',
        verified_at: rejected_profiles.first.verified_at,
      )
    end
  end
end
