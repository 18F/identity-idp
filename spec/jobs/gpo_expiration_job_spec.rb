require 'rails_helper'

RSpec.describe GpoExpirationJob do
  include Rails.application.routes.url_helpers

  subject(:job) { described_class.new(analytics: analytics) }

  let(:analytics) { FakeAnalytics.new }

  let(:usps_confirmation_max_days) { 30 }

  let(:gpo_max_profile_age_to_send_letter_in_days) { 30 }

  let(:expired_timestamp) { Time.zone.now - usps_confirmation_max_days.days - 1.hour }

  let(:not_expired_timestamp) { Time.zone.now - (usps_confirmation_max_days / 2).days }

  let!(:user_with_one_expired_gpo_profile) do
    create(
      :user,
      :with_pending_gpo_profile,
      created_at: expired_timestamp,
    )
  end

  let!(:user_with_one_unexpired_gpo_profile) do
    create(
      :user,
      :with_pending_gpo_profile,
      created_at: not_expired_timestamp,
    )
  end

  let!(:user_with_one_expired_code_and_one_unexpired_code) do
    create(
      :user,
      :with_pending_gpo_profile,
      created_at: expired_timestamp,
    ).tap do |user|
      profile = user.gpo_verification_pending_profile
      create(:gpo_confirmation_code, profile: profile, code_sent_at: not_expired_timestamp)
    end
  end

  before do
    allow(IdentityConfig.store).to receive(:gpo_max_profile_age_to_send_letter_in_days).and_return(
      gpo_max_profile_age_to_send_letter_in_days,
    )
    allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).and_return(
      usps_confirmation_max_days,
    )
  end

  describe '#gpo_profiles_that_should_be_expired' do
    it 'returns the correct profiles' do
      profiles = job.gpo_profiles_that_should_be_expired(as_of: Time.zone.now)

      expect(
        profiles.map do |profile|
          user_fixture_method_for(profile: profile)
        end,
      ).to contain_exactly(
        :user_with_one_expired_gpo_profile,
      )
    end

    context 'when users can request letters beyond initial code expiration period' do
      let(:gpo_max_profile_age_to_send_letter_in_days) { 45 }

      it 'returns profiles for the correct users' do
        profiles = job.gpo_profiles_that_should_be_expired(as_of: Time.zone.now)
        expect(profiles.count).to eql(0)
      end
    end
  end

  describe '#perform' do
    it 'expires the profile' do
      profile = user_with_one_expired_gpo_profile.reload.gpo_verification_pending_profile
      freeze_time do
        expect { job.perform }.to change {
                                    profile.reload.gpo_verification_expired_at
                                  }.to eql(Time.zone.now)
      end
    end

    it 'clears gpo_verification_pending_at' do
      profile = user_with_one_expired_gpo_profile.reload.gpo_verification_pending_profile
      expect { job.perform }.to change { profile.reload.gpo_verification_pending_at }.to eql(nil)
    end

    it 'logged an analytics event' do
      job.perform
      expect(analytics).to have_logged_event(
        :idv_gpo_expired,
        user_id: user_with_one_expired_gpo_profile.uuid,
        user_has_active_profile: false,
        letters_sent: 1,
      )
    end

    context 'when the user has an active profile' do
      let!(:active_profile) do
        create(:profile, :active, user: user_with_one_expired_gpo_profile)
      end
      it 'includes that information in analytics event' do
        job.perform

        expect(analytics).to have_logged_event(
          :idv_gpo_expired,
          user_id: user_with_one_expired_gpo_profile.uuid,
          user_has_active_profile: true,
          letters_sent: 1,
        )
      end
    end

    context 'when the user has multiple codes sent' do
      let!(:extra_code) do
        create(
          :gpo_confirmation_code,
          profile: user_with_one_expired_gpo_profile.gpo_verification_pending_profile,
          code_sent_at: expired_timestamp,
        )
      end

      it 'we note that in the analytics event' do
        job.perform

        expect(analytics).to have_logged_event(
          :idv_gpo_expired,
          user_id: user_with_one_expired_gpo_profile.uuid,
          user_has_active_profile: false,
          letters_sent: 2,
        )
      end
    end

    describe 'limit' do
      let(:limit) { 3 }
      before do
        (0..limit).each do
          create(
            :user,
            :with_pending_gpo_profile,
            created_at: expired_timestamp,
          )
        end
      end
      it 'limits the number of records affected' do
        initial_count = Profile.where.not(gpo_verification_pending_at: nil).count

        job.perform(limit: limit)

        expect(Profile.where.not(gpo_verification_pending_at: nil).count).
          to eql(initial_count - limit)
      end
    end
  end

  def user_fixture_method_for(profile:)
    self.methods.
      map(&:to_s).
      filter { |method| /^user_with_/.match(method) }.
      map(&:to_sym).
      find { |user_fixture_method| profile.user == send(user_fixture_method) }
  end
end
