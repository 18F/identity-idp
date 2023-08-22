require 'rails_helper'

RSpec.describe GpoReminderSender do
  describe '#send_emails' do
    subject(:sender) { GpoReminderSender.new }

    let(:user) { create(:user, :with_pending_gpo_profile) }
    let(:gpo_confirmation_code) do
      user.
        gpo_verification_pending_profile.
        gpo_confirmation_codes.
        first
    end

    let(:fake_analytics) { FakeAnalytics.new }
    let(:wait_for_reminder) { 14.days }
    let(:time_due_for_reminder) { Time.zone.now - wait_for_reminder }
    let(:time_not_yet_due) { time_due_for_reminder + 1.day }
    let(:time_yesterday) { Time.zone.now - 1.day }

    def set_gpo_verification_pending_at(to_time)
      user.
        gpo_verification_pending_profile.
        update(gpo_verification_pending_at: to_time)
    end

    def set_reminder_sent_at(to_time)
      gpo_confirmation_code.update(
        reminder_sent_at: to_time,
      )
    end

    before { allow(Analytics).to receive(:new).and_return(fake_analytics) }

    context 'when no users need a reminder' do
      before { set_gpo_verification_pending_at(time_not_yet_due) }

      it 'sends no emails' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { ActionMailer::Base.deliveries.size }.by(0)
      end

      it 'logs no events' do
        expect { subject.send_emails(time_due_for_reminder) }.
          not_to change { fake_analytics.events.count }
      end
    end

    context 'when a user is due for a reminder' do
      before { set_gpo_verification_pending_at(time_due_for_reminder) }

      it 'sends that user an email' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      it 'logs the email events' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { fake_analytics.events.count }.by(2)

        expect(fake_analytics).to have_logged_event('IdV: gpo reminder email sent')
        expect(fake_analytics).to have_logged_event('Email Sent')
      end

      it 'updates the GPO verification code `reminder_sent_at`' do
        subject.send_emails(time_due_for_reminder)

        expect(gpo_confirmation_code.reminder_sent_at).to be_within(1).of(Time.zone.now)
      end

      context 'and the user has multiple emails' do
        let(:user) { create(:user, :with_pending_gpo_profile, :with_multiple_emails) }

        it 'sends an email to all of them' do
          expect { subject.send_emails(time_due_for_reminder) }.
            to change { ActionMailer::Base.deliveries.size }.by(2)
        end
      end

      context 'but the user has cancelled gpo verification' do
        before do
          Idv::CancelVerificationAttempt.new(user: user).call
        end

        it 'does not send that user an email' do
          expect { subject.send_emails(time_due_for_reminder) }.
            to change { ActionMailer::Base.deliveries.size }.by(0)
        end

        it 'logs no events' do
          expect { subject.send_emails(time_due_for_reminder) }.
            not_to change { fake_analytics.events.count }
        end
      end

      context 'but a reminder has already been sent' do
        before { set_reminder_sent_at(time_yesterday) }

        it 'does not send that user an email' do
          expect { subject.send_emails(time_due_for_reminder) }.
            to change { ActionMailer::Base.deliveries.size }.by(0)
        end

        it 'logs no events' do
          expect { subject.send_emails(time_due_for_reminder) }.
            not_to change { fake_analytics.events.count }
        end
      end

      context 'but the user has completed gpo verification' do
        before do
          otp = 'ABC123'
          pending_profile = user.gpo_verification_pending_profile

          pending_profile.gpo_confirmation_codes = [
            create(
              :gpo_confirmation_code,
              otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
              code_sent_at: Time.zone.now,
              profile: pending_profile,
            ),
          ]

          GpoVerifyForm.new(
            user: user,
            pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE,
            otp: otp,
          ).submit
        end

        it 'does not send that user an email' do
          expect { subject.send_emails(time_due_for_reminder) }.
            to change { ActionMailer::Base.deliveries.size }.by(0)
        end

        it 'logs no events' do
          expect { subject.send_emails(time_due_for_reminder) }.
            not_to change { fake_analytics.events.count }
        end
      end
    end

    context 'when a user is due for a reminder from too long ago' do
      let(:max_age_to_send_letter_in_days) { 30 }

      before do
        set_gpo_verification_pending_at((max_age_to_send_letter_in_days + 1).days.ago)
        allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
          and_return(max_age_to_send_letter_in_days)
      end

      it 'does not send that user an email' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { ActionMailer::Base.deliveries.size }.by(0)
      end

      it 'logs no events' do
        expect { subject.send_emails(time_due_for_reminder) }.
          not_to change { fake_analytics.events.count }
      end
    end

    context 'when a user has two gpo reminders' do
      before do
        set_gpo_verification_pending_at(time_due_for_reminder)

        profile = create(
          :profile,
          :with_pii,
          gpo_verification_pending_at: time_due_for_reminder - 1.day,
          user: user,
        )
        gpo_code = create(:gpo_confirmation_code)
        profile.gpo_confirmation_codes << gpo_code
        device = create(:device, user: user)
        create(:event, user: user, device: device, event_type: :gpo_mail_sent)
      end

      it 'sends that user only one email' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      it 'logs the email events' do
        expect { subject.send_emails(time_due_for_reminder) }.
          to change { fake_analytics.events.count }.by(2)

        expect(fake_analytics).to have_logged_event('IdV: gpo reminder email sent')
        expect(fake_analytics).to have_logged_event('Email Sent')
      end
    end
  end
end
