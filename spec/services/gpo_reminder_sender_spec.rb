require 'rails_helper'

RSpec.shared_examples 'sends no emails' do
  it 'sends no emails' do
    expect { subject.send_emails(time_due_for_reminder) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end

  it 'logs no events' do
    expect { subject.send_emails(time_due_for_reminder) }
      .not_to change { fake_analytics.events.count }
  end
end

RSpec.shared_examples 'sends emails' do |expected_number_of_emails:,
                                         expected_number_of_analytics_events:
                                           expected_number_of_emails|
  it "sends that user #{expected_number_of_emails} email(s)" do
    expect { subject.send_emails(time_due_for_reminder) }
      .to change { ActionMailer::Base.deliveries.size }.by(expected_number_of_emails)
  end

  it 'logs the email events' do
    subject.send_emails(time_due_for_reminder)

    expect(fake_analytics.events['IdV: gpo reminder email sent']&.size).to(
      eq(expected_number_of_analytics_events),
    )
    expect(fake_analytics.events['Email Sent']&.size).to(
      eq(expected_number_of_emails),
    )
  end
end

RSpec.describe GpoReminderSender do
  describe '#send_emails' do
    subject(:sender) { GpoReminderSender.new }

    let!(:user) { create(:user, :with_pending_gpo_profile, code_sent_at: code_sent_at) }
    let(:gpo_confirmation_code) do
      user
        .gpo_verification_pending_profile
        .gpo_confirmation_codes
        .first
    end

    let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
    let(:fake_analytics) { FakeAnalytics.new }
    let(:wait_for_reminder) { 14.days }
    let(:time_due_for_reminder) { Time.zone.now - wait_for_reminder }
    let(:time_not_yet_due) { time_due_for_reminder + 1.day }
    let(:time_yesterday) { Time.zone.now - 1.day }
    let(:time_code_expires) { (IdentityConfig.store.usps_confirmation_max_days + 1).days.ago }

    def set_reminder_sent_at(to_time)
      gpo_confirmation_code.update(
        reminder_sent_at: to_time,
        updated_at: to_time,
      )
    end

    before { allow(Analytics).to receive(:new).and_return(fake_analytics) }

    context 'when no users need a reminder' do
      let(:code_sent_at) { time_not_yet_due }

      include_examples 'sends no emails'
    end

    context 'when a user has old reminded code and new code' do
      let(:code_sent_at) { time_due_for_reminder - 2.days }
      before do
        reminder_timestamp = 1.day.ago
        set_reminder_sent_at(reminder_timestamp)

        # user received reminder email and requests new letter
        new_confirmation_code = create(:gpo_confirmation_code, created_at: reminder_timestamp)
        user.gpo_verification_pending_profile.gpo_confirmation_codes << new_confirmation_code
      end

      include_examples 'sends no emails'
    end

    context 'when a user has very old gpo code and remindable gpo code' do
      let(:code_sent_at) { time_code_expires }

      before do
        reminder_timestamp = time_due_for_reminder - 2.days
        new_confirmation_code = create(:gpo_confirmation_code, created_at: reminder_timestamp)
        user.gpo_verification_pending_profile.gpo_confirmation_codes << new_confirmation_code
      end

      include_examples 'sends emails', expected_number_of_emails: 1
    end

    context 'when a user has requested two letters' do
      let(:code_sent_at) { time_due_for_reminder - 2.days }
      before do
        new_confirmation_code = create(:gpo_confirmation_code, created_at: code_sent_at)
        user.gpo_verification_pending_profile.gpo_confirmation_codes << new_confirmation_code
      end

      include_examples 'sends emails', expected_number_of_emails: 2

      it 'updates the GPO verification code `reminder_sent_at` for both codes' do
        subject.send_emails(time_due_for_reminder)
        user.gpo_verification_pending_profile.gpo_confirmation_codes.each(&:reload)

        expect(user.gpo_verification_pending_profile.gpo_confirmation_codes[0].reminder_sent_at)
          .to be_within(1.second).of(Time.zone.now)
        expect(user.gpo_verification_pending_profile.gpo_confirmation_codes[1].reminder_sent_at)
          .to be_within(1.second).of(Time.zone.now)
      end
    end

    context 'when a user is due for a reminder' do
      let(:code_sent_at) { time_due_for_reminder }

      include_examples 'sends emails', expected_number_of_emails: 1

      it 'updates the GPO verification code `reminder_sent_at`' do
        subject.send_emails(time_due_for_reminder)
        gpo_confirmation_code.reload

        expect(gpo_confirmation_code.reminder_sent_at).to be_within(1.second).of(Time.zone.now)
      end

      context 'and the user has multiple emails' do
        let(:code_sent_at) { time_due_for_reminder - 2.days }
        let!(:user) do
          create(
            :user, :with_pending_gpo_profile, :with_multiple_emails,
            code_sent_at: code_sent_at
          )
        end

        include_examples 'sends emails',
                         expected_number_of_emails: 2,
                         expected_number_of_analytics_events: 1

        it 'updates the GPO verification code `reminder_sent_at`' do
          subject.send_emails(time_due_for_reminder)
          gpo_confirmation_code.reload

          expect(gpo_confirmation_code.reminder_sent_at).to be_within(1.second).of(Time.zone.now)
        end
      end

      context 'but the user has cancelled gpo verification' do
        before { Idv::CancelVerificationAttempt.new(user: user).call }

        include_examples 'sends no emails'
      end

      context 'but a reminder has already been sent' do
        before { set_reminder_sent_at(time_yesterday) }

        include_examples 'sends no emails'
      end

      context 'but the user has completed gpo verification' do
        let(:is_enhanced_ipp) { false }
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
            attempts_api_tracker:,
            user:,
            pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE,
            resolved_authn_context_result: Vot::Parser::Result.no_sp_result.with(
              enhanced_ipp?: is_enhanced_ipp,
            ),
            otp: otp,
          ).submit
        end

        include_examples 'sends no emails'
      end

      context 'but the user has changed their password' do
        before { user.gpo_verification_pending_profile.deactivate(:password_reset) }

        include_examples 'sends no emails'
      end
    end

    context 'when a user is due for a reminder from too long ago' do
      let(:code_sent_at) { time_code_expires }

      include_examples 'sends no emails'
    end

    context 'a user in the in-person flow who also requested a GPO letter' do
      let(:user) { create(:user, :with_pending_in_person_enrollment) }

      before do
        timestamp = time_due_for_reminder
        gpo_code = create(:gpo_confirmation_code, created_at: timestamp)
        user.pending_profile.gpo_confirmation_codes << gpo_code
        user.pending_profile.gpo_verification_pending_at = timestamp
        user.pending_profile.save
      end

      include_examples 'sends emails', expected_number_of_emails: 1
    end
  end
end
