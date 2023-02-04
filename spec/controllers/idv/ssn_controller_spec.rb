require 'rails_helper'

describe Idv::SsnController do
  include IdvHelper

  let(:flow_session) do
    { 'error_message' => nil,
      'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      'pii_from_doc' => Idp::Constants::MOCK_IDV_APPLICANT.dup,
      'threatmetrix_session_id' => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard' }
  end

  let(:user) { build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }

  before do
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :render_404_if_ssn_controller_disabled,
      )
    end

    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'checks that the previous step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_pii_from_doc,
      )
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

      before do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)
      end

      context 'when doc_auth_ssn_controller_enabled' do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
            and_return(true)
        end

        it 'renders the show template' do
          get :show

          expect(response).to render_template :show
        end
      end
    end

    context 'when doc_auth_ssn_controller_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
          and_return(false)
      end

      it 'returns 404' do
        get :show

        expect(response.status).to eq(404)
      end
    end
  end
end
