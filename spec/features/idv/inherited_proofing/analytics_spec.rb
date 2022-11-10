require 'rails_helper'

feature 'Inherited Proofing Analytics Regression', js: true do
  include InheritedProofingHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }
  # rubocop:disable Layout/LineLength
  let(:happy_path_events) do
    {
      'Idv: inherited proofing get started visited' => { flow_path: 'standard', step: 'get_started', step_count: 1, analytics_id: 'Inherited Proofing' },
      'Idv: inherited proofing get started submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'get_started', step_count: 1, analytics_id: 'Inherited Proofing' },
      'Idv: inherited proofing agreement visited' => { flow_path: 'standard', step: 'agreement', step_count: 1, analytics_id: 'Inherited Proofing' },
      'Idv: inherited proofing agreement submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'agreement', step_count: 1, analytics_id: 'Inherited Proofing' },
      'IdV: doc auth verify_wait visited' => { flow_path: 'standard', step: 'verify_wait', step_count: 1, analytics_id: 'Inherited Proofing' },
      'IdV: doc auth optional verify_wait submitted' => { success: true, errors: {}, step: 'verify_wait_step_show', analytics_id: 'Inherited Proofing' },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify_info', step_count: 1, analytics_id: 'Inherited Proofing' },
      'IdV: doc auth verify submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'verify_info', step_count: 1, analytics_id: 'Inherited Proofing' },
    }
  end
  # rubocop:enable Layout/LineLength

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics) do |controller|
      fake_analytics.user = controller.analytics_user
      fake_analytics
    end

    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing?).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing_auth_code).and_return auth_code
    # allow_any_instance_of(InheritedProofingJob).to receive(:build_analytics).
    #   and_return(fake_analytics)
  end

  context 'Happy path' do
    before do
      sign_in_and_2fa_user
      complete_all_inherited_proofing_steps_to_handoff
    end

    it 'records all of the events' do
      happy_path_events.each do |event, attributes|
        expect(fake_analytics).to have_logged_event(event, attributes)
      end
    end
  end
end
