require 'rails_helper'

RSpec.describe Idv::InPerson::SsnController do
  let(:pii_from_user) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_NO_SSN.dup }

  let(:flow_session) do
    { pii_from_user: pii_from_user }
  end

  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    subject.user_session['idv/in_person'] = flow_session
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
    subject.idv_session.flow_path = 'standard'
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::SsnController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    context '#confirm_in_person_address_step_complete' do
      context 'residential address controller flag not enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
            and_return(false)
        end
        it 'redirects if the user hasn\'t completed the address page' do
          subject.user_session['idv/in_person'][:pii_from_user].delete(:address1)
          get :show

          expect(response).to redirect_to idv_in_person_step_url(step: :address)
        end
      end

      context 'residential address controller flag enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
            and_return(true)
        end
        it 'redirects if address page not completed' do
          subject.user_session['idv/in_person'][:pii_from_user].delete(:address1)
          get :show

          expect(response).to redirect_to idv_in_person_proofing_address_url
        end
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: doc auth ssn visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        irs_reproofing: false,
        step: 'ssn',
        same_address_as_id: true,
        pii_like_keypaths: [
          [:same_address_as_id],
          [:proofing_results, :context, :stages, :state_id, :state_id_jurisdiction],
        ],
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template 'idv/shared/ssn'
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

    it 'does not change threatmetrix_session_id when updating ssn' do
      subject.idv_session.ssn = ssn
      expect { get :show }.not_to change { subject.idv_session.threatmetrix_session_id }
    end

    context 'with an ssn in idv_session' do
      let(:referer) { idv_in_person_step_url(step: :address) }
      before do
        subject.idv_session.ssn = ssn
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
  end

  describe '#update' do
    context 'valid ssn' do
      let(:params) { { doc_auth: { ssn: ssn } } }
      let(:analytics_name) { 'IdV: doc auth ssn submitted' }
      let(:analytics_args) do
        {
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'ssn',
          success: true,
          errors: {},
          same_address_as_id: true,
          pii_like_keypaths: [[:same_address_as_id], [:errors, :ssn], [:error_details, :ssn]],
        }.merge(ab_test_args)
      end

      it 'sends analytics_submitted event' do
        put :update, params: params

        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end

      it 'logs attempts api event' do
        expect(@irs_attempts_api_tracker).to receive(:idv_ssn_submitted).with(
          ssn: ssn,
        )

        put :update, params: params
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
          irs_reproofing: false,
          step: 'ssn',
          success: false,
          errors: {
            ssn: ['Enter a nine-digit Social Security number'],
          },
          error_details: { ssn: { invalid: true } },
          same_address_as_id: true,
          pii_like_keypaths: [[:same_address_as_id], [:errors, :ssn], [:error_details, :ssn]],
        }.merge(ab_test_args)
      end

      render_views

      it 'renders the show template with an error message' do
        put :update, params: params

        expect(response).to have_rendered('idv/shared/ssn')
        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        expect(response.body).to include('Enter a nine-digit Social Security number')
      end

      it 'invalidates future steps' do
        expect(subject).to receive(:clear_future_steps!)

        put :update, params: params
      end
    end
  end
end
