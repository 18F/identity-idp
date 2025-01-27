require 'rails_helper'

RSpec.describe Idv::InPerson::SsnController do
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
    controller.idv_session.flow_path = 'standard'
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::SsnController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    context '#confirm_in_person_address_step_complete' do
      it 'redirects if address page not completed' do
        subject.user_session['idv/in_person'][:pii_from_user].delete(:address1)
        get :show

        expect(response).to redirect_to idv_in_person_address_url
      end
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

    it 'adds a threatmetrix session id to idv_session' do
      expect { get :show }.to change { controller.idv_session.threatmetrix_session_id }.from(nil)
    end

    it 'does not change threatmetrix_session_id when updating ssn' do
      controller.idv_session.ssn = ssn
      expect { get :show }.not_to change { controller.idv_session.threatmetrix_session_id }
    end

    context 'with an ssn in idv_session' do
      let(:referer) { idv_in_person_address_url }
      before do
        controller.idv_session.ssn = ssn
        request.env['HTTP_REFERER'] = referer
      end

      context 'referer is not verify_info' do
        it 'redirects to verify_info' do
          get :show

          expect(response).to redirect_to(idv_in_person_verify_info_url)
        end
      end

      context 'referer is verify_info' do
        let(:referer) { idv_in_person_verify_info_url }
        it 'does not redirect' do
          get :show

          expect(response).to render_template 'idv/shared/ssn'
        end
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
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'adds ssn to idv_session' do
        put :update, params: params

        expect(subject.idv_session.ssn).to eq(ssn)
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
          subject.idv_session.ssn = '900-95-7890'

          expect { put :update, params: params }.to change { subject.idv_session.ssn }
            .from('900-95-7890').to(ssn)
          expect(@analytics).to have_logged_event(analytics_name, analytics_args)
        end
      end
    end

    context 'invalid ssn' do
      let(:params) { { doc_auth: { ssn: 'i am not an ssn' } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'ssn',
          success: false,
          errors: {
            ssn: ['Enter a nine-digit Social Security number'],
          },
          error_details: { ssn: { invalid: true } },
        }
      end

      render_views

      it 'renders the show template with an error message' do
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
