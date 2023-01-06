require 'rails_helper'

describe Idv::VerifyInfoController do
  include IdvHelper

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'confirms ssn step complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_ssn_step_complete,
      )
    end
  end

  describe '#show' do
    let(:flow_session) do
      { 'error_message' => nil,
        'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
        :pii_from_doc => Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN,
        'threatmetrix_session_id' => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
        :flow_path => 'standard' }
    end

    before do
      user = build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' })
      stub_verify_steps_one_and_two(user)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
      allow(subject).to receive(:flow_session).and_return(flow_session)
    end

    context 'when verify_info#show' do
      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'sends analytics_visited event' do
        get :show

        expected_name = 'IdV: doc auth verify visited'
        expected_args = {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'verify',
          step_count: 1,
        }

        expect(@analytics).to have_received(:track_event).with(expected_name, expected_args)
      end
    end
  end
end
