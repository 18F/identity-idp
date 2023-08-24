require 'rails_helper'

RSpec.shared_examples 'sends no emails' do
  it 'sends no emails' do
    expect { subject.send_emails(time_due_for_reminder) }.
      not_to change { ActionMailer::Base.deliveries.size }
  end

  it 'logs no events' do
    expect { subject.send_emails(time_due_for_reminder) }.
      not_to change { fake_analytics.events.count }
  end
end

RSpec.shared_examples 'sends emails' do |expected_number_of_emails:,
                                         expected_number_of_analytics_events:
                                           expected_number_of_emails|
  it "sends that user #{expected_number_of_emails} email(s)" do
    expect { subject.send_emails(time_due_for_reminder) }.
      to change { ActionMailer::Base.deliveries.size }.by(expected_number_of_emails)
  end

  it 'logs the email events' do
    subject.send_emails(time_due_for_reminder)

    expect(fake_analytics.events['IdV: gpo reminder email sent'].size).to(
      eq(expected_number_of_analytics_events),
    )
    expect(fake_analytics.events['Email Sent'].size).to(
      eq(expected_number_of_emails),
    )
  end

  it 'updates the GPO verification code `reminder_sent_at`' do
    subject.send_emails(time_due_for_reminder)

    expect(gpo_confirmation_code.reminder_sent_at).to be_within(1.second).of(Time.zone.now)
  end
end

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

    def set_gpo_verification_pending_at(user, to_time)
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
      before { set_gpo_verification_pending_at(user, time_not_yet_due) }

      include_examples 'sends no emails'
    end

    context 'when a user has requested two letters' do
      before do
        set_gpo_verification_pending_at(user, time_due_for_reminder - 2.days)
        new_confirmation_code = create(:gpo_confirmation_code)
        user.gpo_verification_pending_profile.gpo_confirmation_codes << new_confirmation_code
      end

      include_examples 'sends emails', expected_number_of_emails: 2
    end

    context 'when a user is due for a reminder' do
      before { set_gpo_verification_pending_at(user, time_due_for_reminder) }

      include_examples 'sends emails', expected_number_of_emails: 1

      context 'and the user has multiple emails' do
        let(:user) { create(:user, :with_pending_gpo_profile, :with_multiple_emails) }

        include_examples 'sends emails',
                         expected_number_of_emails: 2,
                         expected_number_of_analytics_events: 1
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

        include_examples 'sends no emails'
      end
    end

    context 'when a user is due for a reminder from too long ago' do
      let(:max_age_to_send_letter_in_days) { 42 }

      before do
        set_gpo_verification_pending_at(user, (max_age_to_send_letter_in_days + 1).days.ago)
        allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
          and_return(max_age_to_send_letter_in_days)
      end

      include_examples 'sends no emails'
    end
  end
end
