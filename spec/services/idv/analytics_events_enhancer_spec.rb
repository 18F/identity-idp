require 'rails_helper'

RSpec.describe Idv::AnalyticsEventsEnhancer do
  let(:user) { build(:user) }
  let(:analytics_class) do
    Class.new(FakeAnalytics) do
      include AnalyticsEvents
      prepend Idv::AnalyticsEventsEnhancer

      def idv_final(**kwargs)
        @called_kwargs = kwargs
      end

      attr_reader :user, :called_kwargs

      def initialize(user:)
        @user = user
      end
    end
  end
  let(:analytics) { analytics_class.new(user: user) }

  it 'includes decorated methods' do
    expect(analytics.methods).to include(*described_class::DECORATED_METHODS)
    expect(
      analytics.methods.
        intersection(described_class::DECORATED_METHODS).
        map { |method| analytics.method(method).source_location.first }.
        uniq,
    ).to eq([Idv::AnalyticsEventsEnhancer.const_source_location(:DECORATED_METHODS).first])
  end

  it 'calls analytics method with original and decorated attributes' do
    analytics.idv_final(extra: true)
    expect(analytics.called_kwargs).to eq(extra: true, profile_history: [])
  end

  context 'with anonymous analytics user' do
    let(:user) { AnonymousUser.new }

    it 'calls analytics method with original and decorated attributes' do
      analytics.idv_final(extra: true)

      expect(analytics.called_kwargs).to eq(extra: true, profile_history: [])
    end
  end

  describe 'proofing_components' do
    let(:proofing_components) { nil }

    before do
      user.proofing_component = proofing_components
    end

    context 'without proofing component' do
      it 'calls analytics method with original and decorated attributes' do
        analytics.idv_final(extra: true)

        expect(analytics.called_kwargs).to match(
          extra: true,
          profile_history: [],
        )
      end
    end

    context 'with proofing component' do
      let(:proofing_components) do
        ProofingComponent.new(source_check: Idp::Constants::Vendors::AAMVA)
      end

      it 'calls analytics method with original attributes and proofing_components' do
        analytics.idv_final(extra: true)

        expect(analytics.called_kwargs).to match(
          extra: true,
          profile_history: [],
          proofing_components: kind_of(Idv::ProofingComponentsLogging),
        )
      end
    end
  end

  describe 'active_profile_idv_level' do
    context 'without an active profile' do
      it 'calls analytics method with original attributes but not active_profile_idv_level' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to match(extra: true, profile_history: [])
      end
    end

    context 'with an active profile' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, :active, user: user) }

      it 'calls analytics method with original attributes and active_profile_idv_level' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to include(
          extra: true,
          active_profile_idv_level: 'legacy_unsupervised',
        )
      end
    end
  end

  describe 'pending_profile_idv_level' do
    context 'without a pending profile' do
      it 'calls analytics method with original attributes but not pending_profile_idv_level' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to match(extra: true, profile_history: [])
      end
    end

    context 'with a pending profile' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, :verify_by_mail_pending, user: user) }

      it 'calls analytics method with original attributes and pending_profile_idv_level' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to include(
          pending_profile_idv_level: 'legacy_unsupervised',
        )
      end
    end
  end

  describe 'profile_history' do
    let(:profiles) { nil }

    context 'user has no profiles' do
      it 'logs an empty array' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to eq(extra: true, profile_history: [])
      end
    end

    context 'user has profiles' do
      let(:user) { create(:user) }
      let!(:profiles) do
        [
          create(:profile, :active, user:, created_at: 10.days.ago),
          create(:profile, :verify_by_mail_pending, user:, created_at: 11.days.ago),
        ]
      end

      it 'logs Profiles in created_at order' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to include(:profile_history)
        expect(analytics.called_kwargs[:profile_history].map { |h| h.profile.id }).to eql(
          [
            profiles.last.id,
            profiles.first.id,
          ],
        )
      end

      it 'logs Profiles using ProfileLogging' do
        analytics.idv_final(extra: true)
        expect(analytics.called_kwargs).to include(
          profile_history: [
            kind_of(Idv::ProfileLogging),
            kind_of(Idv::ProfileLogging),
          ],
        )
      end
    end
  end
end
