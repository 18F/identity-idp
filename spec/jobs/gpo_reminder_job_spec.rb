require 'rails_helper'

RSpec.describe GpoReminderJob do
  let(:days_before_sending_reminder) { 12 }
  let(:max_days_ago_to_send_letter) { 27 }

  describe '#perform' do
    subject(:perform) { job.perform(days_before_sending_reminder.days.ago) }

    let(:job) { GpoReminderJob.new }

    let(:gpo_expired_user) { create(:user, :with_pending_gpo_profile) }
    let(:due_for_reminder_user) { create(:user, :with_pending_gpo_profile) }
    let(:not_yet_due_for_reminder_user) { create(:user, :with_pending_gpo_profile) }
    let(:user_with_invalid_profile) { create(:user, :with_pending_gpo_profile) }

    let(:job_analytics) { FakeAnalytics.new }

    before do
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
        and_return(max_days_ago_to_send_letter)
      allow(Analytics).to receive(:new).and_return(job_analytics)

      gpo_expired_user.gpo_verification_pending_profile.update(
        gpo_verification_pending_at: (max_days_ago_to_send_letter + 1).days.ago,
      )

      due_for_reminder_user.gpo_verification_pending_profile.update(
        gpo_verification_pending_at: days_before_sending_reminder.days.ago,
      )

      not_yet_due_for_reminder_user.gpo_verification_pending_profile.update(
        gpo_verification_pending_at: (days_before_sending_reminder - 1).days.ago,
      )

      user_with_invalid_profile.gpo_verification_pending_profile.update(
        gpo_verification_pending_at: days_before_sending_reminder.days.ago,
      )
      user_with_invalid_profile.gpo_verification_pending_profile.deactivate(:password_reset)
    end

    it 'sends only one reminder email, to the correct user' do
      expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to.first).to eq(due_for_reminder_user.email)
      expect(job_analytics).to have_logged_event(
        'IdV: gpo reminder email sent',
        user_id: due_for_reminder_user.uuid,
      )
    end
  end
end
