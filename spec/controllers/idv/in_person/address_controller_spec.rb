require 'rails_helper'

RSpec.describe Idv::InPerson::AddressController do
  include InPersonHelper
  let(:in_person_residential_address_controller_enabled) { true }
  let(:pii_from_user) { Idp::Constants::MOCK_IPP_APPLICANT_SAME_ADDRESS_AS_ID_FALSE.dup }
  let(:user) { build(:user) }
  let(:flow_session) do
    { pii_from_user: pii_from_user }
  end
  let(:flow_path) { 'standard' }
  let(:user_session) do
    { idv: {} }
  end

  before(:each) do
    allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
      and_return(true)
    allow(subject).to receive(:current_user).
      and_return(user)
    allow(subject).to receive(:pii_from_user).and_return(pii_from_user)
    allow(subject).to receive(:flow_session).and_return(flow_session)
    allow(subject).to receive(:flow_path).and_return(flow_path)
    allow(subject).to receive(:user_session).and_return(user_session)
    stub_sign_in(user)
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  # TODO: Update before actions
  describe 'before_actions' do
    context '#render_404_if_in_person_residential_address_controller_enabled not set' do
      context 'flag not set' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
            and_return(nil)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end

      context 'flag not enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
            and_return(false)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end
    end

    context '#confirm_in_person_state_id_step_complete' do
      it 'redirects to state id page if not complete' do
        flow_session[:pii_from_user].delete(:identity_doc_address1)
        get :show

        expect(response).to redirect_to idv_in_person_step_url(step: :state_id)
      end
    end

    context '#confirm_in_person_address_step_needed' do
      context 'step is not needed' do
        # this is no longer true for this b4 action
        it 'redirects to ssn page when same address as id is true' do
          flow_session[:pii_from_user][:same_address_as_id] = 'true'
          get :show
          expect(response).to redirect_to idv_in_person_ssn_url
        end

        it 'redirects to ssn page when address1 present' do
          flow_session[:pii_from_user][:address1] = '123 Main St'
          get :show
          expect(response).to redirect_to idv_in_person_ssn_url
        end
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: in person proofing address visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: flow_path,
        irs_reproofing: false,
        step: 'address',
        step_count: nil,
      }
    end

    context 'with address controller flag enabled' do
      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'logs idv_in_person_proofing_address_visited' do
        get :show

        expect(@analytics).to have_received(
          :track_event,
        ).with(analytics_name, analytics_args)
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
    end
  end

  describe '#update' do
    let(:address1) { '1 FAKE RD' }
    let(:address2) { 'APT 1B' }
    let(:city) { 'GREAT FALLS' }
    let(:zipcode) { '59010' }
    let(:state) { 'Montana' }
    let(:submitted_values) do
      {
        address1:,
        address2:,
        city:,
        zipcode:,
        state:,
      }
    end
    let(:params) { { in_person_address: submitted_values } }
    let(:ssn) { '900123456' }
    let(:user_session) do
      { idv: { ssn: ssn } }
    end
    let(:analytics_name) { 'IdV: in person proofing residential address submitted' }
    let(:analytics_args) do
      {
        success: true,
        errors: { },
      }
    end

    it 'sets values in the flow session' do
      get :update, params: params

      expect(flow_session[:pii_from_user]).to include(
        address1:,
        address2:,
        city:,
        zipcode:,
        state:,
      )
    end

    it 'logs idv_in_person_proofing_address_visited' do
      get :update, params: params

      expect(@analytics).to have_received(
        :track_event,
      ).with(analytics_name, analytics_args)
    end

    context 'when updating the residential address' do
      before(:each) do
        flow_session[:pii_from_user][:address1] = '123 New Residential Ave'
        allow(subject).to receive(:user_session).and_return(user_session)
      end

      context 'user previously selected that the residential address matched state ID' do
        before(:each) do
          flow_session[:pii_from_user][:same_address_as_id] = 'true'
        end

        it 'infers and sets the "same_address_as_id" in the flow session to false' do
          get :update, params: params

          expect(flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
        end
      end

      context 'user previously selected that the residential address did not match state ID' do
        before(:each) do
          flow_session[:pii_from_user][:same_address_as_id] = 'false'
        end

        it 'leaves the "same_address_as_id" in the flow session as false' do
          get :update, params: params

          expect(flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
        end
      end
    end
  end
end
