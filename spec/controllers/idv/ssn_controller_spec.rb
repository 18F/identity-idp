require 'rails_helper'

RSpec.describe Idv::SsnController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      'pii_from_doc' => Idp::Constants::MOCK_IDV_APPLICANT.dup,
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard' }
  end

  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    subject.user_session['idv/doc_auth'] = flow_session
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'checks that the previous step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_document_capture_complete,
      )
    end

    it 'overrides CSPs for ThreatMetrix' do
      expect(subject).to have_actions(
        :before,
        :override_csp_for_threat_metrix_no_fsm,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth ssn visited' }
    let(:analytics_args) do
      {
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'ssn',
      }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog ssn_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.ssn_view_count }.from(0).to(1),
      )
    end

    context 'without a flow session' do
      let(:flow_session) { nil }

      it 'redirects to hybrid_handoff' do
        get :show

        expect(response).to redirect_to(idv_hybrid_handoff_url)
      end
    end

    context 'with an ssn in session' do
      let(:referer) { idv_document_capture_url }
      before do
        flow_session['pii_from_doc'][:ssn] = ssn
        request.env['HTTP_REFERER'] = referer
      end

      context 'referer is not verify_info' do
        it 'redirects to verify_info' do
          get :show

          expect(response).to redirect_to(idv_verify_info_url)
        end
      end

      context 'referer is verify_info' do
        let(:referer) { idv_verify_info_url }
        it 'does not redirect' do
          get :show

          expect(response).to render_template :show
        end
      end
    end

    it 'overrides Content Security Policies for ThreatMetrix' do
      allow(IdentityConfig.store).to receive(:proofing_device_profiling).
        and_return(:enabled)
      get :show

      csp = response.request.content_security_policy

      aggregate_failures do
        expect(csp.directives['script-src']).to include('h.online-metrix.net')
        expect(csp.directives['script-src']).to include("'unsafe-eval'")

        expect(csp.directives['style-src']).to include("'unsafe-inline'")

        expect(csp.directives['child-src']).to include('h.online-metrix.net')

        expect(csp.directives['connect-src']).to include('h.online-metrix.net')

        expect(csp.directives['img-src']).to include('*.online-metrix.net')
      end
    end
  end

  describe '#update' do
    context 'with valid ssn' do
      let(:params) { { doc_auth: { ssn: ssn } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'ssn',
          success: true,
          errors: {},
          pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]],
        }
      end

      it 'merges ssn into pii session value' do
        put :update, params: params

        expect(flow_session['pii_from_doc'][:ssn]).to eq(ssn)
      end

      it 'redirects to address controller for Puerto Rico addresses' do
        flow_session['pii_from_doc'][:state] = 'PR'

        put :update, params: params

        expect(response).to redirect_to(idv_address_url)
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
        put :update, params: params
        subject.threatmetrix_view_variables
        expect(flow_session[:threatmetrix_session_id]).to_not eq(nil)
      end

      it 'does not change threatmetrix_session_id when updating ssn' do
        flow_session['pii_from_doc'][:ssn] = ssn
        put :update, params: params
        session_id = flow_session[:threatmetrix_session_id]
        subject.threatmetrix_view_variables
        expect(flow_session[:threatmetrix_session_id]).to eq(session_id)
      end
    end

    context 'with invalid ssn' do
      let(:ssn) { 'i am not an ssn' }
      let(:params) { { doc_auth: { ssn: ssn } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'Doc Auth',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'ssn',
          success: false,
          errors: {
            ssn: [t('idv.errors.pattern_mismatch.ssn')],
          },
          error_details: { ssn: [:invalid] },
          pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]],
        }
      end

      render_views

      it 'renders the show template with an error message' do
        put :update, params: params

        expect(response).to have_rendered(:show)
        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        expect(response.body).to include(t('idv.errors.pattern_mismatch.ssn'))
      end
    end

    context 'when pii_from_doc is not present' do
      before do
        flow_session[:flow_path] = 'standard'
        flow_session.delete('pii_from_doc')
      end

      it 'redirects to DocumentCaptureController on standard flow' do
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_document_capture_url
      end

      it 'redirects to LinkSentController on hybrid flow' do
        flow_session[:flow_path] = 'hybrid'
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_link_sent_url
      end

      it 'redirects to hybrid_handoff if there is no flow_path' do
        flow_session[:flow_path] = nil
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_hybrid_handoff_url
      end
    end
  end
end
