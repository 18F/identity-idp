require 'rails_helper'

RSpec.describe GpoReminderJob do
  let(:days_before_sending_reminder) { 12 }
  let(:max_days_ago_to_send_letter) { 27 }

  describe '#perform' do
    subject(:perform) { job.perform(days_before_sending_reminder.days.ago) }

    let(:job) { GpoReminderJob.new }

    let!(:gpo_expired_user) do
      create(
        :user, :with_pending_gpo_profile,
        code_sent_at: (max_days_ago_to_send_letter + 1).days.ago
      )
    end
    let!(:due_for_reminder_user) do
      create(
        :user, :with_pending_gpo_profile,
        code_sent_at: days_before_sending_reminder.days.ago
      )
    end
    let!(:not_yet_due_for_reminder_user) do
      create(
        :user, :with_pending_gpo_profile,
        code_sent_at: (days_before_sending_reminder - 1).days.ago
      )
    end
    let!(:user_with_invalid_profile) do
      create(
        :user, :with_pending_gpo_profile,
        code_sent_at: days_before_sending_reminder.days.ago
      )
    end
    let!(:user_with_new_gpo_code) do
      create(
        :user, :with_pending_gpo_profile,
        code_sent_at: (max_days_ago_to_send_letter + 1).days.ago
      )
    end

    let(:job_analytics) { FakeAnalytics.new }

    before do
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days)
        .and_return(max_days_ago_to_send_letter)
      allow(Analytics).to receive(:new).and_return(job_analytics)

      user_with_invalid_profile.gpo_verification_pending_profile.deactivate(:password_reset)

      new_confirmation_code = create(:gpo_confirmation_code, created_at: 1.day.ago)
      user_with_new_gpo_code.gpo_verification_pending_profile.gpo_confirmation_codes <<
        new_confirmation_code
    end

    it 'sends only one reminder email, to the correct user' do
      expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to.first).to eq(due_for_reminder_user.email)
      expect(job_analytics).to have_logged_event(
        'IdV: gpo reminder email sent',
        user_id: due_for_reminder_user.uuid,
      )
    end

    context 'when the user has another active profile' do
      let!(:active_profile) do
        create(:profile, :active, user: due_for_reminder_user)
      end

      it 'does not send an email' do
        expect { perform }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
