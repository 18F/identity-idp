require 'rails_helper'

RSpec.describe Idv::InPerson::AddressController do
  include InPersonHelper

  let(:pii_from_user) { Idp::Constants::MOCK_IPP_APPLICANT_SAME_ADDRESS_AS_ID_FALSE.dup }
  let(:user) { build(:user) }
  let(:flow_session) do
    { pii_from_user: pii_from_user }
  end
  let(:ssn) { nil }

  before do
    allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
      and_return(true)
    allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
      and_return(true)
    allow(subject).to receive(:current_user).
      and_return(user)
    allow(subject).to receive(:pii_from_user).and_return(pii_from_user)
    allow(subject).to receive(:flow_session).and_return(flow_session)
    stub_sign_in(user)
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.ssn = ssn
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

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
      it 'remains on page when referer is verify info' do
        subject.request = idv_in_person_verify_info_url
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
        irs_reproofing: false,
        opted_in_to_in_person_proofing: nil,
        step: 'address',
        step_count: nil,
        lexisnexis_instant_verify_workflow_ab_test_bucket: :default,
        pii_like_keypaths: [[:same_address_as_id],
                            [:proofing_results, :context, :stages, :state_id,
                             :state_id_jurisdiction]],
        same_address_as_id: false,
        skip_hybrid_handoff: nil,
      }
    end

    context 'with address controller flag enabled' do
      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'redirects to ssn page when address1 present' do
        flow_session[:pii_from_user][:address1] = '123 Main St'

        get :show

        expect(response).to redirect_to idv_in_person_ssn_url
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
    context 'valid address details' do
      let(:address1) { '1 FAKE RD' }
      let(:address2) { 'APT 1B' }
      let(:city) { 'GREAT FALLS' }
      let(:zipcode) { '59010' }
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
      let(:ssn) { '900123456' }
      let(:analytics_name) { 'IdV: in person proofing residential address submitted' }
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'address',
          lexisnexis_instant_verify_workflow_ab_test_bucket: :default,
          pii_like_keypaths: [[:same_address_as_id],
                              [:proofing_results, :context, :stages, :state_id,
                               :state_id_jurisdiction]],
          same_address_as_id: false,
          skip_hybrid_handoff: nil,
        }
      end

      it 'sets values in the flow session' do
        put :update, params: params

        expect(flow_session[:pii_from_user]).to include(
          address1:,
          address2:,
          city:,
          zipcode:,
          state:,
        )
      end

      it 'logs idv_in_person_proofing_address_visited' do
        put :update, params: params

        expect(@analytics).to have_received(
          :track_event,
        ).with(analytics_name, analytics_args)
      end

      context 'when updating the residential address' do
        before do
          flow_session[:pii_from_user][:address1] = '123 New Residential Ave'
        end

        context 'user previously selected that the residential address matched state ID' do
          before do
            flow_session[:pii_from_user][:same_address_as_id] = 'true'
          end

          it 'infers and sets the "same_address_as_id" in the flow session to false' do
            put :update, params: params

            expect(flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
          end
        end

        context 'user previously selected that the residential address did not match state ID' do
          before do
            flow_session[:pii_from_user][:same_address_as_id] = 'false'
          end

          it 'leaves the "same_address_as_id" in the flow session as false' do
            put :update, params: params

            expect(flow_session[:pii_from_user][:same_address_as_id]).to eq('false')
          end
        end
      end
    end

    context 'invalid address details' do
      let(:address1) { '1 F@KE RD' }
      let(:address2) { '@?T 1B' }
      let(:city) { 'GR3AT F&LLS' }
      let(:zipcode) { '59010' }
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
          success: false,
          errors: {},
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'address',
          lexisnexis_instant_verify_workflow_ab_test_bucket: :default,
          pii_like_keypaths: [[:same_address_as_id],
                              [:proofing_results, :context, :stages, :state_id,
                               :state_id_jurisdiction]],
          same_address_as_id: false,
          skip_hybrid_handoff: nil,
        }
      end

      it 'does not proceed to next page' do
        put :update, params: params

        expect(response).to have_rendered(:show)
        expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
      end
    end
  end
end
