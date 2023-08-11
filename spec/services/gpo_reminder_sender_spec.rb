require 'rails_helper'

RSpec.describe GpoReminderSender do
  describe '#send_emails' do
    let(:user) { create(:user, :with_pending_gpo_profile) }

    def set_gpo_verification_pending_at(to_time)
      user.gpo_verification_pending_profile.update(gpo_verification_pending_at: to_time)
    end

    def set_reminder_sent_at(to_time)
      gpo_confirmation_code = user.gpo_verification_pending_profile.gpo_confirmation_codes.first
      gpo_confirmation_code.reminder_sent_at = to_time
      gpo_confirmation_code.save
    end

    context 'when no users need a reminder' do
      before { set_gpo_verification_pending_at(Time.zone.now - 13.days) }

      it 'sends no emails' do
        expect { subject.send_emails }.to change { ActionMailer::Base.deliveries.size }.by(0)
      end
    end

    context 'when a user is due for a reminder' do
      before { set_gpo_verification_pending_at(Time.zone.now - 14.days) }

      it 'sends that user an email' do
        expect { subject.send_emails }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      context 'but a reminder has already been sent' do
        before { set_reminder_sent_at(Time.zone.now - 1.day) }

        it 'does not send that user an email' do
          expect { subject.send_emails }.to change { ActionMailer::Base.deliveries.size }.by(0)
        end
      end
    end
  end
end
