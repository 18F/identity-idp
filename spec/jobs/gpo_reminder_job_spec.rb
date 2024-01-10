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
    let(:user_with_new_gpo_code) { create(:user, :with_pending_gpo_profile) }

    let(:job_analytics) { FakeAnalytics.new }

    before do
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
        and_return(max_days_ago_to_send_letter)
      allow(Analytics).to receive(:new).and_return(job_analytics)

      set_gpo_verification_pending_at(gpo_expired_user, (max_days_ago_to_send_letter + 1).days.ago)

      set_gpo_verification_pending_at(due_for_reminder_user, days_before_sending_reminder.days.ago)

      set_gpo_verification_pending_at(
        not_yet_due_for_reminder_user,
        (days_before_sending_reminder - 1).days.ago,
      )

      set_gpo_verification_pending_at(
        user_with_invalid_profile,
        days_before_sending_reminder.days.ago,
      )
      user_with_invalid_profile.gpo_verification_pending_profile.deactivate(:password_reset)

      set_gpo_verification_pending_at(
        user_with_new_gpo_code,
        (max_days_ago_to_send_letter + 1).days.ago,
      )
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
  end

  def set_gpo_verification_pending_at(user, to_time)
    user.
      gpo_verification_pending_profile.
      update(gpo_verification_pending_at: to_time)

    user.
      gpo_verification_pending_profile.
      gpo_confirmation_codes.each do |code|
        code.update(code_sent_at: to_time, created_at: to_time, updated_at: to_time)
      end
  end
end
