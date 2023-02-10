require 'rails_helper'

describe Idv::SsnController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      'pii_from_doc' => Idp::Constants::MOCK_IDV_APPLICANT.dup,
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
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
  end

  context 'when doc_auth_ssn_controller_enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_ssn_controller_enabled).
        and_return(true)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    describe '#show' do
      let(:analytics_name) { 'IdV: doc auth ssn visited' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'ssn',
          step_count: 1,
        }
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

    describe '#update' do
      context 'with valid ssn' do
        let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }
        let(:params) { { doc_auth: { ssn: ssn } } }
        let(:analytics_name) { 'IdV: doc auth ssn submitted' }
        let(:analytics_args) do
          {
            analytics_id: 'Doc Auth',
            flow_path: 'standard',
            irs_reproofing: false,
            step: 'ssn',
            step_count: 1,
          }
        end

        it 'merges ssn into pii session value' do
          put :update, params: params

          expect(flow_session['pii_from_doc'][:ssn]).to eq(ssn)
        end

        it 'sends analytics_submitted event with correct step count' do
          get :show
          put :update, params: params

          expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        end

        it 'logs attempts api event' do
          expect(@irs_attempts_api_tracker).to receive(:idv_ssn_submitted).with(
            ssn: ssn,
          )
          put :update, params: params
        end

        context 'with existing session applicant' do
          it 'clears applicant' do
            subject.idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT

            put :update, params: params

            expect(subject.idv_session.applicant).to be_blank
          end
        end

        it 'adds a threatmetrix session id to flow session' do
          subject.extra_view_variables
          expect(flow_session[:threatmetrix_session_id]).to_not eq(nil)
        end

        it 'does not change threatmetrix_session_id when updating ssn' do
          flow_session['pii_from_doc'][:ssn] = ssn
          put :update, params: params
          session_id = flow_session[:threatmetrix_session_id]
          subject.extra_view_variables
          expect(flow_session[:threatmetrix_session_id]).to eq(session_id)
        end
      end

      context 'when pii_from_doc is not present' do
        it 'marks previous step as incomplete' do
          flow_session.delete('pii_from_doc')
          flow_session['Idv::Steps::DocumentCaptureStep'] = true
          put :update
          expect(flow_session['Idv::Steps::DocumentCaptureStep']).to eq nil
          expect(response.status).to eq 302
        end
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
