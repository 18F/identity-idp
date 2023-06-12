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

    expect(analytics.called_kwargs).to eq(extra: true, proofing_components: nil)
  end

  context 'with anonymous analytics user' do
    let(:user) { AnonymousUser.new }

    it 'calls analytics method with original and decorated attributes' do
      analytics.idv_final(extra: true)

      expect(analytics.called_kwargs).to eq(extra: true, proofing_components: nil)
    end
  end

  context 'with proofing component' do
    let(:proofing_components) do
      ProofingComponent.new(source_check: Idp::Constants::Vendors::AAMVA)
    end

    before do
      user.proofing_component = proofing_components
    end

    it 'calls analytics method with original and decorated attributes' do
      analytics.idv_final(extra: true)

      expect(analytics.called_kwargs).to match(
        extra: true,
        proofing_components: kind_of(Idv::ProofingComponentsLogging),
      )
    end
  end
end
