require 'rails_helper'

RSpec.describe Idv::InPerson::StateIdController do
  include FlowPolicyHelper
  include InPersonHelper

  let(:user) { build(:user) }
  let(:enrollment) { InPersonEnrollment.new }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
      and_return(true)
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    subject.idv_session.ssn = nil # This made specs pass. Might need more investigation.
    stub_analytics
  end

  describe 'before_actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :set_usps_form_presenter,
      )
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
        step: 'state_id',
      }
    end

    it 'has non-nil presenter' do
      get :show
      expect(assigns(:presenter)).to be_kind_of(Idv::InPerson::UspsFormPresenter)
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

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
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
    let(:first_name) { 'Natalya' }
    let(:last_name) { 'Rostova' }
    let(:formatted_dob) { InPersonHelper::GOOD_DOB }
    let(:dob) do
      parsed_dob = Date.parse(formatted_dob)
      { month: parsed_dob.month.to_s,
        day: parsed_dob.day.to_s,
        year: parsed_dob.year.to_s }
    end
    # residential
    let(:address1) { InPersonHelper::GOOD_ADDRESS1 }
    let(:address2) { InPersonHelper::GOOD_ADDRESS2 }
    let(:city) { InPersonHelper::GOOD_CITY }
    let(:state) { InPersonHelper::GOOD_STATE }
    let(:zipcode) { InPersonHelper::GOOD_ZIPCODE }
    let(:id_number) { 'ABC123234' }
    let(:state_id_jurisdiction) { 'AL' }
    let(:identity_doc_address1) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1 }
    let(:identity_doc_address2) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2 }
    let(:identity_doc_city) { InPersonHelper::GOOD_IDENTITY_DOC_CITY }
    let(:identity_doc_address_state) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS_STATE }
    let(:identity_doc_zipcode) { InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE }
    context 'with values submitted' do
      let(:invalid_params) do
        { identity_doc: {
          first_name: 'S@ndy!',
          last_name:,
          same_address_as_id: 'true', # value on submission
          identity_doc_address1:,
          identity_doc_address2:,
          identity_doc_city:,
          state_id_jurisdiction:,
          id_number:,
          identity_doc_address_state:,
          identity_doc_zipcode:,
          dob:,
        } }
      end
      let(:params) do
        { identity_doc: {
          first_name:,
          last_name:,
          same_address_as_id: 'true', # value on submission
          identity_doc_address1:,
          identity_doc_address2:,
          identity_doc_city:,
          state_id_jurisdiction:,
          id_number:,
          identity_doc_address_state:,
          identity_doc_zipcode:,
          dob:,
        } }
      end
      let(:analytics_name) { 'IdV: in person proofing state_id submitted' }
      let(:analytics_args) do
        {
          success: true,
          errors: {},
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'state_id',
          birth_year: dob[:year],
          document_zip_code: identity_doc_zipcode&.slice(0, 5),
        }
      end

      it 'logs idv_in_person_proofing_state_id_submitted' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'renders show when validation errors are present when first visiting page' do
        put :update, params: invalid_params

        expect(subject.idv_session.ssn).to eq(nil)
        expect(subject.extra_view_variables[:updating_state_id]).to eq(false)
        expect(response).to render_template :show
      end

      it 'renders show when validation errors are present when re-visiting page' do
        subject.idv_session.ssn = '123-45-6789'
        put :update, params: invalid_params

        expect(subject.extra_view_variables[:updating_state_id]).to eq(true)
        expect(response).to render_template :show
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
        expect(pii_from_user[:dob]).to eq formatted_dob
        expect(pii_from_user[:identity_doc_zipcode]).to eq identity_doc_zipcode
        expect(pii_from_user[:identity_doc_address_state]).to eq identity_doc_address_state
        # param from form as id_number but is renamed to state_id_number on update
        expect(pii_from_user[:state_id_number]).to eq id_number
      end
    end

    context 'when same_address_as_id is...' do
      let(:pii_from_user) { subject.user_session['idv/in_person'][:pii_from_user] }

      context 'changed from "true" to "false"' do
        let(:params) do
          {
            identity_doc: {
              first_name:,
              last_name:,
              same_address_as_id: 'false', # value on submission
              identity_doc_address1:,
              identity_doc_address2:,
              identity_doc_city:,
              state_id_jurisdiction:,
              id_number:,
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

          build_pii_before_state_id_update

          # since same_address_as_id was initially true, pii includes residential address attrs,
          # which are the same as state id address attrs, on re-visiting state id pg
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
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
          { identity_doc: {
            first_name:,
            last_name:,
            same_address_as_id: 'true', # value on submission
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            state_id_jurisdiction:,
            id_number:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
            dob:,
          } }
        end

        it <<~EOS.squish do
          retains identity_doc_ attrs/value ands addr attr
          with same value as identity_doc in flow session
        EOS
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          build_pii_before_state_id_update(same_address_as_id: 'false')

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
          { identity_doc: {
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
          build_pii_before_state_id_update(same_address_as_id: 'false')

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
