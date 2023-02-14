require 'rails_helper'

describe Idv::InPerson::VerifyInfoController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      :pii_from_doc => Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup,
      :flow_path => 'standard' }
  end

  let(:user) { build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
  end

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

    it 'confirms verify step not already complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_profile_not_already_confirmed,
      )
    end

    it 'renders 404 if feature flag not set' do
      allow(IdentityConfig.store).to receive(:doc_auth_in_person_verify_info_controller_enabled).
        and_return(false)

      get :show

      expect(response).to be_not_found
    end
  end

  context 'when doc_auth_ssn_controller_enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_in_person_verify_info_controller_enabled).
        and_return(true)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    describe '#show' do
      let(:analytics_name) { 'IdV: doc auth verify visited' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'verify',
          step_count: 1,
        }
      end

      context 'when doc_auth_in_person_verify_info_controller_enabled' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
            and_return(true)
        end

        it 'renders the show template' do
          get :show

          expect(response).to render_template :show
        end

        it 'sends analytics_visited event' do
          get :show

          expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        end

        it 'sends correct step count to analytics' do
          get :show
          get :show
          analytics_args[:step_count] = 2

          expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        end
      end
    end
  end
end
