require 'rails_helper'

RSpec.describe SendGpoCodeExpirationNoticesJob do
  include Rails.application.routes.url_helpers

  let(:job) { described_class.new(analytics: analytics) }

  let(:analytics) { FakeAnalytics.new }

  let(:usps_confirmation_max_days) { 30 }

  let(:expired_timestamp) { (usps_confirmation_max_days.days + 1).ago }

  let(:more_expired_timestamp) { expired_timestamp - 1.day }

  let(:not_expired_timestamp) { (usps_confirmation_max_days.days - 1).ago }

  let(:expired_too_long_ago_timestamp) { expired_timestamp - 30.days }

  let!(:user_with_expired_code) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_timestamp)
  end

  let!(:user_with_two_expired_codes) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_timestamp).tap do |user|
      profile = user.gpo_verification_pending_profile
      create(:gpo_confirmation_code, profile: profile, code_sent_at: more_expired_timestamp)
    end
  end

  let!(:user_who_already_got_an_expiration_notice) do
    create(
      :user,
      :with_pending_gpo_profile,
      code_sent_at: expired_timestamp,
    ).tap do |user|
      code = user.
        gpo_verification_pending_profile.
        gpo_confirmation_codes.first

      code.update!(expiration_notice_sent_at: Time.zone.now)
    end
  end

  let!(:user_who_completed_gpo) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_timestamp).tap do |user|
      profile = user.gpo_verification_pending_profile
      profile.remove_gpo_deactivation_reason
      profile.activate
    end
  end

  let!(:users_with_profiles_in_invalid_states) do
    reasons = %i[
      password_reset
      encryption_error
      verification_cancelled
      gpo_verification_pending_NO_LONGER_USED
      in_person_verification_pending_NO_LONGER_USED
    ]

    reasons.map do |reason|
      create(:user, :with_pending_gpo_profile, code_sent_at: expired_timestamp).tap do |user|
        profile = user.gpo_verification_pending_profile
        profile.deactivate(reason)
      end
    end
  end

  let!(:user_who_started_gpo_but_then_verified_a_different_way) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_timestamp).tap do |user|
      create(:profile, :active, :verified, :with_pii, user: user)
    end
  end

  let!(:user_who_has_an_unexpired_code) do
    create(:user, :with_pending_gpo_profile, code_sent_at: not_expired_timestamp)
  end

  let!(:user_with_code_that_expired_too_long_ago) do
    create(:user, :with_pending_gpo_profile, code_sent_at: expired_too_long_ago_timestamp)
  end

  before do
    allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).
      and_return(usps_confirmation_max_days)
  end

  it 'has the expected number of test users configured' do
    expect(User.count).to eql(12)
  end

  describe '#codes_to_send_notifications_for' do
    it 'returns correct codes requiring notification' do
      expect(job.codes_to_send_notifications_for.to_a).to eql(
        [
          user_with_expired_code.
            gpo_verification_pending_profile.
            gpo_confirmation_codes.first,
          user_with_two_expired_codes.
            gpo_verification_pending_profile.
            gpo_confirmation_codes.first,
        ],
      )
    end
  end

  describe '#perform' do
    let(:users_who_should_be_notified) do
      [
        user_with_expired_code,
        user_with_two_expired_codes,
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
              user.gpo_verification_pending_profile.gpo_verification_pending_at,
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
        user_with_expired_code.
          gpo_verification_pending_profile.
          gpo_confirmation_codes.
          first,
        user_with_two_expired_codes.
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
