require 'rails_helper'

RSpec.describe GpoReminderSender do
  describe '#send_emails' do
    WAIT_BEFORE_SENDING_REMINDER = 14.days
    TIME_DUE_FOR_REMINDER = Time.zone.now - WAIT_BEFORE_SENDING_REMINDER
    TIME_NOT_YET_DUE = TIME_DUE_FOR_REMINDER + 1.day
    TIME_YESTERDAY = Time.zone.now - 1.day

    subject(:sender) { GpoReminderSender.new(fake_analytics) }

    let(:user) { create(:user, :with_pending_gpo_profile) }
    let(:fake_analytics) { FakeAnalytics.new }

    def set_gpo_verification_pending_at(to_time)
      user.gpo_verification_pending_profile.update(gpo_verification_pending_at: to_time)
    end

    def set_reminder_sent_at(to_time)
      user.
        gpo_verification_pending_profile.
        gpo_confirmation_codes.
        first.
        update(reminder_sent_at: to_time)
    end

    context 'when no users need a reminder' do
      before { set_gpo_verification_pending_at(TIME_NOT_YET_DUE) }

      it 'sends no emails' do
        expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
          to change { ActionMailer::Base.deliveries.size }.by(0)
      end

      it 'logs no events' do
        expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
          not_to change { fake_analytics.events.count }
      end
    end

    context 'when a user is due for a reminder' do
      before { set_gpo_verification_pending_at(TIME_DUE_FOR_REMINDER) }

      it 'sends that user an email' do
        expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
          to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      it 'logs an event' do
        subject.send_emails(TIME_DUE_FOR_REMINDER)

        expect(fake_analytics).to have_logged_event('IdV: gpo reminder email sent')
      end

      context 'and the user has multiple emails' do
        let(:user) { create(:user, :with_pending_gpo_profile, :with_multiple_emails) }

        it 'sends an email to all of them' do
          expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
            to change { ActionMailer::Base.deliveries.size }.by(2)
        end
      end

      context 'but a reminder has already been sent' do
        before { set_reminder_sent_at(TIME_YESTERDAY) }

        it 'does not send that user an email' do
          expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
            to change { ActionMailer::Base.deliveries.size }.by(0)
        end

        it 'logs no events' do
          expect { subject.send_emails(TIME_DUE_FOR_REMINDER) }.
            not_to change { fake_analytics.events.count }
        end
      end
    end
  end
end
