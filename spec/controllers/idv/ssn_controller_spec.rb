require 'rails_helper'

RSpec.describe Idv::SsnController do
  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT.dup
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
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
        :override_csp_for_threat_metrix,
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
      }.merge(ab_test_args)
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

    it 'adds a threatmetrix session id to idv_session' do
      expect { get :show }.to change { subject.idv_session.threatmetrix_session_id }.from(nil)
    end

    context 'with an ssn in idv_session' do
      let(:referer) { idv_document_capture_url }
      before do
        subject.idv_session.ssn = ssn
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
        }.merge(ab_test_args)
      end

      it 'updates idv_session.ssn' do
        expect { put :update, params: params }.to change { subject.idv_session.ssn }.
          from(nil).to(ssn)
      end

      context 'with a Puerto Rico address and pii_from_doc in idv_session' do
        it 'redirects to address controller after user enters their SSN' do
          subject.idv_session.pii_from_doc[:state] = 'PR'

          put :update, params: params

          expect(response).to redirect_to(idv_address_url)
        end

        it 'redirects to the verify info controller if a user is updating their SSN' do
          subject.idv_session.ssn = ssn
          subject.idv_session.pii_from_doc[:state] = 'PR'

          put :update, params: params

          expect(response).to redirect_to(idv_verify_info_url)
        end
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

      it 'does not change threatmetrix_session_id when updating ssn' do
        subject.idv_session.ssn = ssn
        put :update, params: params
        session_id = subject.idv_session.threatmetrix_session_id
        subject.threatmetrix_view_variables
        expect(subject.idv_session.threatmetrix_session_id).to eq(session_id)
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
          pii_like_keypaths: [[:same_address_as_id], [:errors, :ssn], [:error_details, :ssn]],
        }.merge(ab_test_args)
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
        subject.idv_session.flow_path = 'standard'
        subject.idv_session.pii_from_doc = nil
      end

      it 'redirects to DocumentCaptureController on standard flow' do
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_document_capture_url
      end

      it 'redirects to LinkSentController on hybrid flow' do
        subject.idv_session.flow_path = 'hybrid'
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_link_sent_url
      end

      it 'redirects to hybrid_handoff if there is no flow_path' do
        subject.idv_session.flow_path = nil
        put :update
        expect(response.status).to eq 302
        expect(response).to redirect_to idv_hybrid_handoff_url
      end
    end
  end
end
