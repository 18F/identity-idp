require 'rails_helper'

RSpec.describe SendGpoCodeExpirationNoticesJob do
  include Rails.application.routes.url_helpers

  let(:job) { described_class.new(analytics: analytics) }

  let(:analytics) { FakeAnalytics.new }

  let(:usps_confirmation_max_days) { 30 }

  let(:min_age_for_expiration_notice_in_days) { usps_confirmation_max_days.days + 1.day }

  let(:expired_but_not_yet_notifiable_timestamp) { usps_confirmation_max_days.days.ago }

  let(:expired_and_notifiable_timestamp) { min_age_for_expiration_notice_in_days.ago - 1.day }

  let(:too_expired_to_notify_timestamp) { expired_but_not_yet_notifiable_timestamp - 3.days }

  let(:not_expired_timestamp) { usps_confirmation_max_days.days.ago + 1.day }

  let!(:user_with_expired_code_who_should_be_notified) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_and_notifiable_timestamp)
  end

  let!(:user_with_code_thats_not_expired_enough) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_but_not_yet_notifiable_timestamp)
  end

  let!(:user_with_two_expired_and_notifiable_codes) do
    create(
      :user,
      :with_pending_gpo_profile,
      code_sent_at: expired_and_notifiable_timestamp,
    ).tap do |user|
      profile = user.gpo_verification_pending_profile
      create(
        :gpo_confirmation_code,
        profile: profile,
        code_sent_at: expired_and_notifiable_timestamp - 1.second,
      )
    end
  end

  let!(:user_who_already_got_an_expiration_notice) do
    create(
      :user,
      :with_pending_gpo_profile,
      code_sent_at: expired_and_notifiable_timestamp,
    ).tap do |user|
      code = user.
        gpo_verification_pending_profile.
        gpo_confirmation_codes.first

      code.update(expiration_notice_sent_at: Time.zone.now)
    end
  end

  let!(:user_who_completed_gpo) do
    create(
      :user,
      :with_pending_gpo_profile,
      code_sent_at: expired_and_notifiable_timestamp,
    ).tap do |user|
      profile = user.gpo_verification_pending_profile
      profile.remove_gpo_deactivation_reason
      profile.activate
    end
  end

  let(:deactivation_reasons) do
    %i[
      password_reset
      encryption_error
      verification_cancelled
      gpo_verification_pending_NO_LONGER_USED
      in_person_verification_pending_NO_LONGER_USED
    ]
  end

  let!(:users_with_profiles_with_deactivation_reasons) do
    deactivation_reasons.map do |reason|
      create(
        :user,
        :with_pending_gpo_profile,
        code_sent_at: expired_and_notifiable_timestamp,
      ).tap do |user|
        profile = user.gpo_verification_pending_profile
        profile.deactivate(reason)
      end
    end
  end

  let!(:user_who_started_gpo_but_then_verified_a_different_way) do
    create(
      :user,
      :with_pending_gpo_profile,
      code_sent_at: expired_and_notifiable_timestamp,
    ).tap do |user|
      create(:profile, :active, :verified, :with_pii, user: user)
    end
  end

  let!(:user_who_has_an_unexpired_code) do
    create(:user, :with_pending_gpo_profile, code_sent_at: not_expired_timestamp)
  end

  let!(:user_with_code_that_expired_too_long_ago) do
    create(:user, :with_pending_gpo_profile, code_sent_at: too_expired_to_notify_timestamp)
  end

  before do
    allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
      and_return(usps_confirmation_max_days)
  end

  describe '#calculate_notification_window_bounds' do
    it 'finds the right bounds' do
      bounds = job.calculate_notification_window_bounds(
        as_of: Time.zone.parse('2023-11-25 13:14:15'),
      )
      expected_min = Time.zone.parse('2023-10-24 00:00:00')
      expected_max = Time.zone.parse('2023-10-26 00:00:00')

      expect(bounds).to eql(expected_min..expected_max)
    end
  end

  describe '#codes_to_send_notifications_for' do
    # Helper method to map a GpoConfirmationCode back to the `let!()` in this
    # file that defines its user.
    def user_for(code:)
      users = %i[
        user_with_expired_code_who_should_be_notified
        user_with_code_thats_not_expired_enough
        user_with_two_expired_and_notifiable_codes
        user_who_already_got_an_expiration_notice
        user_who_completed_gpo
        user_who_started_gpo_but_then_verified_a_different_way
        user_who_has_an_unexpired_code
        user_with_code_that_expired_too_long_ago
      ]

      users.each do |sym|
        user = send(sym)
        return sym if code.profile.user == user
      end

      deactivation_reasons.with_index.each do |reason, index|
        user = users_with_profiles_in_invalid_states[index]
        return reason if user == code.profile.user
      end

      nil
    end

    it 'returns correct codes requiring notification' do
      # First check to make sure we're getting codes for the users we expect
      expect(
        job.codes_to_send_notifications_for.map { |code| user_for(code: code) },
      ).to contain_exactly(
        :user_with_expired_code_who_should_be_notified,
        :user_with_two_expired_and_notifiable_codes,
      )

      expect(job.codes_to_send_notifications_for.to_a).to contain_exactly(
        user_with_expired_code_who_should_be_notified.
          gpo_verification_pending_profile.
          gpo_confirmation_codes.first,
        user_with_two_expired_and_notifiable_codes.
          gpo_verification_pending_profile.
          gpo_confirmation_codes.first,
      )
    end
  end

  describe '#perform' do
    let(:users_who_should_be_notified) do
      [
        user_with_expired_code_who_should_be_notified,
        user_with_two_expired_and_notifiable_codes,
      ]
    end

    it 'sends one email to each user' do
      expect { job.perform }.to change { ActionMailer::Base.deliveries.count }.by(2)
      users_who_should_be_notified.each do |user|
        expect_delivered_email(
          to: [user.email],
          subject: t('user_mailer.gpo_code_expired.subject'),
          body: [
            I18n.l(
              user.gpo_verification_pending_profile.gpo_confirmation_codes.first.code_sent_at,
              format: :event_date,
            ),
            idv_url,
          ],
        )
      end
    end

    it 'logs an analytics event for each user' do
      job.perform

      actual_events = analytics.events[:idv_gpo_expiration_email_sent]
      expect(actual_events.count).to eql(users_who_should_be_notified.count)

      users_who_should_be_notified.each do |user|
        expect(analytics).to have_logged_event(
          :idv_gpo_expiration_email_sent,
          user_id: user.uuid,
        )
      end
    end

    it 'marks codes as having had an expiration notice sent' do
      codes_that_should_receive_notices = [
        user_with_expired_code_who_should_be_notified.
          gpo_verification_pending_profile.
          gpo_confirmation_codes.
          first,
        user_with_two_expired_and_notifiable_codes.
          gpo_verification_pending_profile.
          gpo_confirmation_codes.
          order(code_sent_at: :desc).
          first,
      ]

      freeze_time do
        job.perform
        codes_that_should_receive_notices.each do |code|
          code.reload
          expect(code.expiration_notice_sent_at).to eql(Time.zone.now)
        end
      end
    end

    it 'does not send anything on a second call' do
      job.perform
      expect { job.perform }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
