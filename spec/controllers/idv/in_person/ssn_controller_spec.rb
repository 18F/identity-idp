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
    subject.user_session['idv/in_person'] = flow_session
    stub_analytics
    subject.idv_session.flow_path = 'standard'
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::SsnController.step_info).to be_valid
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth ssn visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        step: 'ssn',
        same_address_as_id: true,
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
      expect { get :show }.to change { subject.idv_session.threatmetrix_session_id }.from(nil)
    end

    it 'does not change threatmetrix_session_id when updating ssn' do
      subject.idv_session.ssn = ssn
      subject.idv_session.threatmetrix_session_id = 'a-random-id'
      expect { get :show }.not_to change { subject.idv_session.threatmetrix_session_id }
    end

    context 'with an ssn in idv_session' do
      before do
        subject.idv_session.ssn = ssn
      end

      it 'renders normally' do
        get :show

        expect(response).to render_template('idv/shared/ssn')
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
          errors: {},
          same_address_as_id: true,
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
          same_address_as_id: true,
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
