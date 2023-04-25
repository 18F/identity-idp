require 'rails_helper'

RSpec.describe FraudRejectionDailyJob do
  subject(:job) { FraudRejectionDailyJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(job).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    it 'rejects profiles which have been review pending for more than 30 days' do
      create(
        :profile,
        fraud_review_pending: true,
        fraud_review_pending_at: 31.days.ago,
      )
      create(
        :profile,
        fraud_review_pending: true,
        fraud_review_pending_at: 20.days.ago,
      )

      rejected_profiles = Profile.where(fraud_rejection: true)

      expect { job.perform(Time.zone.today) }.to change { rejected_profiles.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'Fraud: Automatic Fraud Rejection',
        rejection_date: Time.zone.today,
        fraud_review_pending_at: rejected_profiles.first.fraud_review_pending_at,
      )
    end
  end
end
