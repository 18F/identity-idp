require 'rails_helper'

RSpec.describe Idv::InPerson::AddressController do
  include FlowPolicyHelper
  include InPersonHelper

  let(:user) { build(:user) }
  let(:enrollment) do
    create(:in_person_enrollment, :establishing, user: user)
  end
  let(:pii_from_user) { Idp::Constants::MOCK_IPP_APPLICANT_SAME_ADDRESS_AS_ID_FALSE }

  before do
    stub_sign_in(user)
    stub_up_to(:ipp_state_id, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.idv_session.opted_in_to_in_person_proofing = true
    subject.user_session['idv/in_person'] = {
      pii_from_user: pii_from_user,
    }
    stub_analytics
  end

  describe '#step_info' do
    let(:address1) { Idp::Constants::MOCK_IDV_APPLICANT[:address1] }
    let(:address2) { 'APT 1B' }
    let(:city) { Idp::Constants::MOCK_IDV_APPLICANT[:city] }
    let(:zipcode) { Idp::Constants::MOCK_IDV_APPLICANT[:zipcode] }
    let(:state) { 'Montana' }
    let(:params) do
      { in_person_address: {
        address1: address1,
        address2: address2,
        city: city,
        zipcode: zipcode,
        state: state,
      } }
    end

    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::AddressController.step_info).to be_valid
    end

    context 'preconditions' do
      context 'when ipp_state_id steps have been completed' do
        before do
          allow(subject.idv_session).to receive(:ipp_state_id_complete?).and_return(true)
        end

        it 'returns true' do
          expect(
            described_class.step_info.preconditions.call(idv_session: subject.idv_session, user:),
          ).to be(true)
        end
      end

      context 'when ipp_state_id steps have not been completed' do
        before do
          allow(subject.idv_session).to receive(:ipp_state_id_complete?).and_return(false)
        end

        context 'when in_person passports are allowed' do
          before do
            allow(subject.idv_session).to receive(:in_person_passports_allowed?).and_return(true)
          end

          it 'returns true' do
            expect(
              described_class.step_info.preconditions.call(idv_session: subject.idv_session, user:),
            ).to be(true)
          end
        end

        context 'when in_person passports are not allowed' do
          before do
            allow(subject.idv_session).to receive(:in_person_passports_allowed?).and_return(false)
          end

          it 'returns false' do
            expect(
              described_class.step_info.preconditions.call(idv_session: subject.idv_session, user:),
            ).to be(false)
          end
        end
      end
    end

    context 'undo_step' do
      before do
        allow(subject.idv_session).to receive(:invalidate_in_person_address_step!)
        described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
      end

      it 'invalidates the ipp_address step' do
        expect(subject.idv_session).to have_received(:invalidate_in_person_address_step!)
      end
    end
  end

  describe 'before_actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :set_usps_form_presenter,
        :confirm_step_allowed,
      )
    end

    context '#step_info preconditions check if state id is complete' do
      before do
        subject.user_session['idv/in_person'][:pii_from_user].delete(:identity_doc_address1)
        subject.user_session['idv/in_person'][:pii_from_user].delete(:identity_doc_address2)
        subject.user_session['idv/in_person'][:pii_from_user].delete(:identity_doc_city)
        subject.user_session['idv/in_person'][:pii_from_user].delete(:identity_doc_zipcode)
        subject.user_session['idv/in_person'][:pii_from_user].delete(:identity_doc_state)
      end

      it 'redirects to state id page if not complete' do
        get :show

        expect(response).to redirect_to idv_in_person_state_id_url
      end
    end

    context '#confirm_in_person_address_step_needed' do
      before do
        request.env['HTTP_REFERER'] = idv_in_person_verify_info_url
      end
      it 'remains on page when referer is verify info' do
        get :show

        expect(response).to render_template :show
        expect(response).to_not redirect_to(idv_in_person_ssn_url)
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: in person proofing address visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        step: 'address',
      }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'logs idv_in_person_proofing_address_visited' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'has correct extra_view_variables' do
      expect(subject.extra_view_variables).to include(
        form: Idv::InPerson::AddressForm,
        updating_address: false,
      )

      expect(subject.extra_view_variables[:pii]).to_not have_key(
        :address1,
      )
    end

    it 'has non-nil presenter' do
      get :show
      expect(assigns(:presenter)).to be_kind_of(Idv::InPerson::UspsFormPresenter)
    end
  end

  describe '#update' do
    context 'valid address details' do
      let(:address1) { Idp::Constants::MOCK_IDV_APPLICANT[:address1] }
      let(:address2) { 'APT 1B' }
      let(:city) { Idp::Constants::MOCK_IDV_APPLICANT[:city] }
      let(:zipcode) { Idp::Constants::MOCK_IDV_APPLICANT[:zipcode] }
      let(:state) { 'Montana' }
      let(:params) do
        { in_person_address: {
          address1: address1,
          address2: address2,
          city: city,
          zipcode: zipcode,
          state: state,
        } }
      end
      let(:analytics_name) { 'IdV: in person proofing residential address submitted' }
      let(:analytics_args) do
        {
          success: true,
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'address',
          current_address_zip_code: '59010',
        }
      end

      it 'sets values in the flow session' do
        put :update, params: params

        expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
          address1:,
          address2:,
          city:,
          zipcode:,
          state:,
        )
      end

      it 'enables the user to navigate to the ssn page after entering their residential address' do
        put :update, params: params

        expect(response).to redirect_to(idv_in_person_ssn_url)
      end

      it 'logs idv_in_person_proofing_address_submitted with 5-digit zipcode' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      context 'when updating the residential address' do
        before do
          stub_up_to(:ipp_verify_info, idv_session: subject.idv_session)
          subject.user_session['idv/in_person'][:pii_from_user][:address1] =
            '123 New Residential Ave'
        end

        context 'user previously selected that the residential address matched state ID' do
          before do
            subject.user_session['idv/in_person'][:pii_from_user][:same_address_as_id] = 'true'
          end

          it 'infers and sets the "same_address_as_id" in the flow session to false' do
            put :update, params: params

            expect(subject.user_session['idv/in_person'][:pii_from_user][:same_address_as_id])
              .to eq('false')
          end
        end

        context 'user previously selected that the residential address did not match state ID' do
          before do
            subject.user_session['idv/in_person'][:pii_from_user][:same_address_as_id] = 'false'
          end

          it 'leaves the "same_address_as_id" in the flow session as false' do
            put :update, params: params

            expect(subject.user_session['idv/in_person'][:pii_from_user][:same_address_as_id])
              .to eq('false')
          end
        end
      end

      it 'invalidates future steps, but does not clear ssn' do
        subject.idv_session.ssn = '123-45-6789'
        expect(subject).to receive(:clear_future_steps_from!).and_call_original

        expect { put :update, params: params }.not_to change { subject.idv_session.ssn }
      end
    end

    context 'invalid address details' do
      let(:params) do
        { in_person_address: {
          address1: '1 F@KE RD',
          address2: '@?T 1B',
          city: 'GR3AT F&LLS',
          zipcode: '59010',
          state: 'Montana',
        } }
      end
      let(:analytics_name) { 'IdV: in person proofing residential address submitted' }
      let(:analytics_args) do
        {
          success: false,
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'address',
          current_address_zip_code: '59010',
        }
      end

      before do
        put :update, params: params
      end

      it 'does not proceed to next page' do
        expect(response).to have_rendered(:show)
      end

      it 'logs idv_in_person_proofing_address_submitted without zipcode' do
        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end
    end
  end
end
