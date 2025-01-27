require 'rails_helper'

RSpec.describe Idv::AnalyticsEventsEnhancer do
  let(:user) { build(:user) }
  let(:sp) { nil }
  let(:user_session) { nil }
  let(:session) do
    if user_session.present?
      {
        'warden.user.user.session' => user_session,
      }
    end
  end

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
    let(:user_session) { {} }

    context 'without proofing component' do
      it 'calls analytics method with original attributes' do
        analytics.idv_test_method(extra: true)

        expect(analytics.called_kwargs).to match(
          extra: true,
        )
      end
    end

    context 'with proofing components' do
      before do
        # Set up the user_session so it looks like the user's been through doc auth
        idv_session = Idv::Session.new(
          user_session:,
          current_user: user,
          service_provider: sp,
        )
        idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT
      end

      it 'calls analytics method with original attributes and proofing_components' do
        analytics.idv_test_method(extra: true)

        expect(analytics.called_kwargs).to eql(
          extra: true,
          proofing_components: {
            document_type: 'state_id',
          },
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

  describe 'profile_history' do
    let(:profiles) { nil }
    let(:include_profile_history?) { true }

    before do
      if include_profile_history?
        allow(
          stub_const(
            'Idv::AnalyticsEventsEnhancer::METHODS_WITH_PROFILE_HISTORY',
            %i[idv_test_method],
          ),
        )
      end
    end

    context 'user has no profiles' do
      it 'logs an empty array' do
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to eq(extra: true)
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
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to include(:profile_history)
        expect(analytics.called_kwargs[:profile_history].map { |h| h.profile.id }).to eql(
          [
            profiles.last.id,
            profiles.first.id,
          ],
        )
      end

      it 'logs Profiles using ProfileLogging' do
        analytics.idv_test_method(extra: true)
        expect(analytics.called_kwargs).to include(
          active_profile_idv_level: 'legacy_unsupervised',
          profile_history: all(be_instance_of(Idv::ProfileLogging)),
        )
      end

      context 'method is not opted into profile_history' do
        let(:include_profile_history?) { false }

        it 'does not log profile_history' do
          analytics.idv_test_method(extra: true)
          expect(analytics.called_kwargs).not_to include(:profile_history)
        end
      end
    end
  end

  describe 'valid configuration' do
    let(:explicitly_ignored_methods) do
      described_class.const_get(:IGNORED_METHODS).sort
    end

    let(:explicitly_enhanced_methods) do
      described_class.const_get(:METHODS_WITH_PROFILE_HISTORY).sort
    end

    let(:explicitly_referenced_methods) do
      [*explicitly_ignored_methods, *explicitly_enhanced_methods].sort
    end

    let(:idv_event_methods) do
      AnalyticsEvents.instance_methods(false)
        .filter { |n| n.start_with?('idv_') }
        .sort
    end

    it 'only references known AnalyticsEvents methods' do
      found_methods = (idv_event_methods & explicitly_referenced_methods).sort
      expect(found_methods).to eq(explicitly_referenced_methods)
    end

    it 'does not both ignore and enhance the same method' do
      expect(explicitly_ignored_methods).to_not include(*explicitly_enhanced_methods)
    end
  end
end
