require 'rails_helper'

RSpec.describe FraudRejectionDailyJob do
  subject(:job) { FraudRejectionDailyJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  describe '#perform' do
    it 'rejects profiles which have been review pending for more than 30 days' do
      rejectedable_profile = create(:profile, fraud_review_pending_at: 31.days.ago)
      create(:profile, fraud_review_pending_at: 20.days.ago)

      rejected_profiles = Profile.where.not(fraud_rejection_at: nil)

      allow(job).to receive(:analytics).with(user: rejectedable_profile.user)
        .and_return(job_analytics)

      expect { job.perform(Time.zone.today) }.to change { rejected_profiles.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'Fraud: Automatic Fraud Rejection',
        fraud_rejection_at: rejected_profiles.first.fraud_rejection_at,
      )
    end

    it 'rejects in-person profiles which have been review pending for more than 30 days' do
      rejectedable_profile = create(:profile, fraud_review_pending_at: 31.days.ago)
      enrollment = create(
        :in_person_enrollment, :in_fraud_review, profile: rejectedable_profile,
                                                 user: rejectedable_profile.user
      )
      create(:profile, fraud_review_pending_at: 20.days.ago)

      rejected_profiles = Profile.where.not(fraud_rejection_at: nil)

      allow(job).to receive(:analytics).with(user: rejectedable_profile.user)
        .and_return(job_analytics)

      expect { job.perform(Time.zone.today) }.to change { rejected_profiles.count }.by(1)
      expect(job_analytics).to have_logged_event(
        'Fraud: Automatic Fraud Rejection',
        fraud_rejection_at: rejected_profiles.first.fraud_rejection_at,
      )
      expect(enrollment.reload.status).to eq('failed')
    end
  end
end
