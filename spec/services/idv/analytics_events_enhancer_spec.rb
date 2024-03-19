require 'rails_helper'

RSpec.describe Idv::AnalyticsEventsEnhancer do
  let(:user) { build(:user) }
  let(:sp) { nil }
  let(:session) { nil }
  let(:analytics_class) do
    Class.new(FakeAnalytics) do
      include AnalyticsEvents
      include(
        Module.new do
          def idv_test_method(**extra)
            track_event(:idv_test_method, **extra)
          end
        end,
      )
      prepend Idv::AnalyticsEventsEnhancer

      attr_reader :called_kwargs

      def initialize(user:, sp:, session:)
        @user = user
        @sp = sp
        @session = session
      end

      def track_event(_event, **kwargs)
        @called_kwargs = kwargs
      end
    end
  end
  let(:analytics) { analytics_class.new(user: user, sp: sp, session: session) }

  it 'enhances idv_ methods by default, but ignores those in IGNORED_METHODS' do
    enhancer_source_file = described_class.const_source_location(:IGNORED_METHODS).first

    idv_methods = analytics_class.instance_methods.filter { |method| /^idv_/.match?(method) }

    idv_methods.each do |method_name|
      method = analytics_class.instance_method(method_name)
      method_source_file = method.source_location.first

      should_be_ignored = described_class.const_get(:IGNORED_METHODS).include?(method_name)
      if should_be_ignored
        expect(method_source_file).not_to eql(enhancer_source_file),
                                          "#{method_name} should not be enhanced"
      else
        expect(
          method_source_file,
        ).to eql(enhancer_source_file), "#{method_name} should be enhanced"
       end
    end
  end

  context 'with anonymous analytics user' do
    let(:user) { AnonymousUser.new }

    it 'calls analytics method with original attributes' do
      analytics.idv_test_method(extra: true)

      expect(analytics.called_kwargs).to eq(extra: true)
    end
  end

  describe 'proofing_components' do
    let(:proofing_components) { nil }

    before do
      user.proofing_component = proofing_components
    end

    context 'without proofing component' do
      it 'calls analytics method with original attributes' do
        analytics.idv_test_method(extra: true)

        expect(analytics.called_kwargs).to match(
          extra: true,
        )
      end
    end

    context 'with proofing component' do
      let(:proofing_components) do
        ProofingComponent.new(source_check: Idp::Constants::Vendors::AAMVA)
      end

      it 'calls analytics method with original attributes and proofing_components' do
        analytics.idv_test_method(extra: true)

        expect(analytics.called_kwargs).to match(
          extra: true,
          proofing_components: kind_of(Idv::ProofingComponentsLogging),
        )
      end
    end
  end

  describe 'active_profile_idv_level' do
    context 'without an active profile' do
      it 'calls analytics method with original attributes but not active_profile_idv_level' do
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to match(extra: true)
      end
    end

    context 'with an active profile' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, :active, user: user) }

      it 'calls analytics method with original attributes and active_profile_idv_level' do
        analytics.idv_test_method(extra: true)
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
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to match(extra: true)
      end
    end

    context 'with a pending profile' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, :verify_by_mail_pending, user: user) }

      it 'calls analytics method with original attributes and pending_profile_idv_level' do
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to include(
          pending_profile_idv_level: 'legacy_unsupervised',
        )
      end
    end
  end
end
