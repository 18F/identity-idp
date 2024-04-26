require 'rails_helper'

RSpec.describe Idv::InPerson::StateIdController do
  include FlowPolicyHelper
  include InPersonHelper

  let(:user) { build(:user) }
  let(:enrollment) { InPersonEnrollment.new }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
      and_return(true)
    allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
      and_return(true)
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    subject.idv_session.ssn = nil # This made specs pass. Might need more investigation.
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    context '#render_404_if_controller_not_enabled' do
      context 'flag not set' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
            and_return(nil)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end

      context 'flag not enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_state_id_controller_enabled).
            and_return(false)
        end
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end
    end

    context '#confirm_establishing_enrollment' do
      let(:enrollment) { nil }
      it 'redirects to document capture if not complete' do
        get :show

        expect(response).to redirect_to idv_document_capture_url
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: in person proofing state_id visited' }
    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        irs_reproofing: false,
        opted_in_to_in_person_proofing: nil,
        step: 'state_id',
        pii_like_keypaths: [[:same_address_as_id],
                            [:proofing_results, :context, :stages, :state_id,
                             :state_id_jurisdiction]],
      }.merge(ab_test_args)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'pii_from_user is nil' do
      it 'renders the show template' do
        subject.user_session['idv/in_person'].delete(:pii_from_user)
        get :show

        expect(response).to render_template :show
      end
    end

    it 'logs idv_in_person_proofing_state_id_visited' do
      get :show

      expect(@analytics).to have_received(
        :track_event,
      ).with(analytics_name, analytics_args)
    end

    it 'has correct extra_view_variables' do
      expect(subject.extra_view_variables).to include(
        form: Idv::StateIdForm,
        updating_state_id: false,
      )

      expect(subject.extra_view_variables[:pii]).to_not have_key(
        :address1,
      )
    end
  end

  describe '#update' do
    context 'with values submitted' do
      let(:first_name) { 'Natalya' }
      let(:last_name) { 'Rostova' }
      let(:dob) { '1980-01-01' }
      let(:identity_doc_address_state) { 'Nevada' }
      let(:state_id_number) { 'ABC123234' }
      let(:params) do
        { state_id: {
          first_name: first_name,
          last_name: last_name,
          dob: dob,
          identity_doc_address_state: identity_doc_address_state,
          state_id_number: state_id_number,
        } }
      end
      let(:analytics_name) { 'IdV: in person proofing state_id submitted' }
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          irs_reproofing: false,
          step: 'state_id',
          pii_like_keypaths: [[:same_address_as_id],
                              [:proofing_results, :context, :stages, :state_id,
                               :state_id_jurisdiction]],
          same_address_as_id: false,
        }.merge(ab_test_args)
      end

      it 'logs idv_in_person_proofing_state_id_visited' do
        put :update, params: params

        expect(@analytics).to have_received(
          :track_event,
        ).with(analytics_name, analytics_args)
      end

      it 'invalidates future steps, but does not clear ssn' do
        subject.idv_session.ssn = '123-45-6789'
        expect(subject).to receive(:clear_future_steps_from!).and_call_original

        expect { put :update, params: params }.not_to change { subject.idv_session.ssn }
      end

      it 'sets values in flow session' do
        Idv::StateIdForm::ATTRIBUTES.each do |attr|
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
        end

        put :update, params: params

        pii_from_user = subject.user_session['idv/in_person'][:pii_from_user]
        expect(pii_from_user[:first_name]).to eq first_name
        expect(pii_from_user[:last_name]).to eq last_name
        expect(pii_from_user[:dob]).to eq dob
        expect(pii_from_user[:identity_doc_address_state]).to eq identity_doc_address_state
        expect(pii_from_user[:state_id_number]).to eq state_id_number
      end

      context 'receives hash dob' do
        let(:dob) do
          {
            day: '3',
            month: '9',
            year: '1988',
          }
        end

        it 'converts the date when setting it in flow session' do
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key :dob

          put :update, params: params

          expect(subject.user_session['idv/in_person'][:pii_from_user][:dob]).to eq '1988-09-03'
        end
      end
    end

    context 'when same_address_as_id is...' do
      let(:pii_from_user) { subject.user_session['idv/in_person'][:pii_from_user] }
      let(:first_name) { 'Natalya' }
      let(:last_name) { 'Rostova' }
      let(:dob) { InPersonHelper::GOOD_DOB }
      # residential
      let(:address1) { InPersonHelper::GOOD_ADDRESS1 }
      let(:address2) { InPersonHelper::GOOD_ADDRESS2 }
      let(:city) { InPersonHelper::GOOD_CITY }
      let(:state) { InPersonHelper::GOOD_STATE }
      let(:zipcode) { InPersonHelper::GOOD_ZIPCODE }
      # identity_doc_
      let(:state_id_number) { 'ABC123234' }
      let(:identity_doc_address1) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1 }
      let(:identity_doc_address2) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2 }
      let(:identity_doc_city) { InPersonHelper::GOOD_IDENTITY_DOC_CITY }
      let(:identity_doc_address_state) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS_STATE }
      let(:identity_doc_zipcode) { InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE }

      context 'changed from "true" to "false"' do
        let(:params) do
          {
            state_id: {
              first_name:,
              last_name:,
              same_address_as_id: 'false', # value on submission
              identity_doc_address1:,
              identity_doc_address2:,
              identity_doc_city:,
              state_id_jurisdiction: 'AL',
              state_id_number:,
              identity_doc_address_state:,
              identity_doc_zipcode:,
              dob:,
            },
          }
        end

        it 'retains identity_doc_ attrs/value but removes addr attr in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          make_pii

          # pii includes address attrs on re-visiting state id pg
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )

          # On Verify, user changes response from "Yes,..." to
          # "No, I live at a different address", see submitted_values above
          put :update, params: params

          # retains identity_doc_ attributes and values in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
          )

          # removes address attributes (non identity_doc_ attributes) in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).not_to include(
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )
        end
      end

      context 'changed from "false" to "true"' do
        let(:params) do
          { state_id: {
            dob:,
            same_address_as_id: 'true', # value on submission
            address1:, # address1 and identity_doc_address1 is innitially different
            address2:,
            city:,
            state:,
            zipcode:,
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
          } }
        end

        it 'retains identity_doc_ attrs/value ands addr attr
        with same value as identity_doc in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          make_pii(same_address_as_id: 'false')

          # On Verify, user changes response from "No,..." to
          # "Yes, I live at the address on my state-issued ID
          put :update, params: params
          # expect addr attr values to the same as the identity_doc attr values
          expect(pii_from_user[:address1]).to eq identity_doc_address1
          expect(pii_from_user[:address2]).to eq identity_doc_address2
          expect(pii_from_user[:city]).to eq identity_doc_city
          expect(pii_from_user[:state]).to eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to eq identity_doc_zipcode
        end
      end

      context 'not changed from "false"' do
        let(:params) do
          { state_id: {
            dob:,
            same_address_as_id: 'false',
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
          } }
        end
        it 'retains identity_doc_ and addr attrs/value in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          # User picks "No, I live at a different address" on state ID
          make_pii(same_address_as_id: 'false')

          # On Verify, user does not changes response "No,..."
          put :update, params: params

          # retains identity_doc_ & addr attributes and values in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )

          # those values are different
          pii_from_user = subject.user_session['idv/in_person'][:pii_from_user]
          expect(pii_from_user[:address1]).to_not eq identity_doc_address1
          expect(pii_from_user[:address2]).to_not eq identity_doc_address2
          expect(pii_from_user[:city]).to_not eq identity_doc_city
          expect(pii_from_user[:state]).to_not eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to_not eq identity_doc_zipcode
        end
      end
    end
  end
end
