require 'rails_helper'

RSpec.describe GpoReminderJob do
  describe '#perform' do
    subject(:perform) { GpoReminderJob.new.perform(Time.zone.now - 14.days) }

    before do
      create(:user, :with_pending_gpo_profile).
        pending_profile.
        update(
          gpo_verification_pending_at: Time.zone.now - 14.days,
        )
    end

    it 'sends reminder emails' do
      expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
