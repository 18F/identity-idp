require 'rails_helper'

RSpec.describe Idv::InPerson::SsnController do
  include FlowPolicyHelper

  let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_NO_SSN.dup }

  let(:flow_session) do
    { pii_from_user: pii_from_user }
  end

  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    controller.user_session['idv/in_person'] = flow_session
    stub_analytics
    stub_attempts_tracker
    controller.idv_session.flow_path = 'standard'
    controller.idv_session.skip_doc_auth_from_handoff = true
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::SsnController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    before do
      stub_up_to(:ipp_state_id, idv_session: subject.idv_session)
      subject.user_session['idv/in_person'][:pii_from_user].delete(:address1)
      allow(user).to receive(:has_establishing_in_person_enrollment?).and_return(true)
    end
    it 'redirects if address page not completed' do
      get :show

      expect(response).to redirect_to idv_in_person_address_url
    end

    it 'checks that step is allowed' do
      expect(subject).to have_actions(
        :before,
        :confirm_step_allowed,
      )
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    let(:analytics_name) { 'IdV: doc auth ssn visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        step: 'ssn',
      }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template 'idv/shared/ssn'
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'updates DocAuthLog ssn_view_count' do
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :show }.to(
        change { doc_auth_log.reload.ssn_view_count }.from(0).to(1),
      )
    end

    context 'threatmetrix_session_id is nil' do
      it 'adds a threatmetrix session id to idv_session' do
        expect { get :show }.to change { controller.idv_session.threatmetrix_session_id }.from(nil)
      end

      it 'sets a threatmetrix_session_id when updating ssn' do
        controller.idv_session.ssn = ssn
        expect { get :show }.to change { controller.idv_session.threatmetrix_session_id }.from(nil)
      end
    end

    context 'threatmetrix_session_id is not nil' do
      before do
        stub_up_to(:ipp_ssn, idv_session: controller.idv_session)
      end
      it 'does not change threatmetrix_session_id when updating ssn' do
        controller.idv_session.ssn = ssn
        expect { get :show }.not_to change { controller.idv_session.threatmetrix_session_id }
      end
    end

    context 'with ThreatMetrix profiling disabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
          .and_return(false)
      end

      it 'does not override CSPs for ThreatMetrix' do
        expect(controller).not_to receive(:override_csp_for_threat_metrix)

        response
      end
    end

    context 'with ThreatMetrix profiling enabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
          .and_return(true)
      end

      it 'overrides CSPs for ThreatMetrix' do
        expect(controller).to receive(:override_csp_for_threat_metrix)

        response
      end
    end
  end

  describe '#update' do
    context 'valid ssn' do
      let(:params) { { doc_auth: { ssn: ssn } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'ssn',
          success: true,
        }
      end

      it 'sends analytics_submitted event' do
        expect(@attempts_api_tracker).to receive(:idv_ssn_submitted).with(
          success: true,
          ssn:,
          failure_reason: nil,
        )
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'adds the ssn to idv_session' do
        put :update, params: params

        expect(subject.idv_session.ssn).to eq(ssn)
      end

      context 'when the submitted ssn includes dashes' do
        let(:ssn) { '123-45-6789' }
        it 'adds the normalized ssn to idv_session' do
          put :update, params: params

          expect(subject.idv_session.ssn).to eq('123456789')
        end
      end

      it 'invalidates steps after ssn' do
        subject.idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT

        put :update, params: params

        expect(subject.idv_session.applicant).to be_blank
      end

      it 'redirects to the expected page' do
        put :update, params: params

        expect(response).to redirect_to idv_in_person_verify_info_url
      end

      context 'when the user has previously submitted an ssn' do
        let(:analytics_args) do
          {
            analytics_id: 'In Person Proofing',
            flow_path: 'standard',
            step: 'ssn',
            success: true,
            previous_ssn_edit_distance: 6,
          }
        end

        it 'updates idv_session.ssn' do
          subject.idv_session.ssn = '900957890'

          expect { put :update, params: params }.to change { subject.idv_session.ssn }
            .from('900957890').to(ssn)
          expect(@analytics).to have_logged_event(analytics_name, analytics_args)
        end
      end
    end

    context 'invalid ssn' do
      let(:ssn) { 'i am not an ssn' }
      let(:params) { { doc_auth: { ssn: } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'ssn',
          success: false,
          error_details: { ssn: { invalid: true } },
        }
      end

      render_views

      it 'renders the show template with an error message' do
        expect(@attempts_api_tracker).to receive(:idv_ssn_submitted).with(
          success: false,
          ssn:,
          failure_reason: { ssn: [:invalid] },
        )
        put :update, params: params

        expect(response).to have_rendered('idv/shared/ssn')
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
        expect(response.body).to include('Enter a nine-digit Social Security number')
      end

      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)

        put :update, params: params
      end
    end
  end
end
