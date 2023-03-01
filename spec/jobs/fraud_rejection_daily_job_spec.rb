require 'rails_helper'

RSpec.describe FraudRejectionDailyJob do
  describe '#perform' do
    subject(:perform) { FraudRejectionDailyJob.new.perform }

    it 'rejects profiles which have been review pending for more than 30 days' do
      create(:profile, fraud_review_pending: true, verified_at: 31.days.ago)
      create(:profile, fraud_review_pending: true, verified_at: 20.days.ago)

      rejected_profiles = Profile.where(fraud_rejection: true)
      expect { perform }.to change { rejected_profiles.count }.by(1)
    end
  end
end
