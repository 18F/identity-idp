require 'rails_helper'

RSpec.describe Idv::Steps::InPerson::StateIdStep do
  include InPersonHelper
  let(:submitted_values) { {} }
  let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
  let(:user) { build(:user) }
  let(:enrollment) { InPersonEnrollment.new }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      params: params,
      current_user: user,
      url_options: {},
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person')
  end

  subject(:step) do
    Idv::Steps::InPerson::StateIdStep.new(flow)
  end

  describe '#call' do
    context 'with values submitted' do
      let(:first_name) { 'Natalya' }
      let(:last_name) { 'Rostova' }
      let(:dob) { '1980-01-01' }
      let(:identity_doc_address_state) { 'Nevada' }
      let(:state_id_number) { 'ABC123234' }
      let(:submitted_values) do
        {
          first_name: first_name,
          last_name: last_name,
          dob: dob,
          identity_doc_address_state: identity_doc_address_state,
          state_id_number: state_id_number,
        }
      end

      before do
        allow(user).to receive(:establishing_in_person_enrollment).
          and_return(enrollment)
      end

      it 'sets values in flow session' do
        Idv::StateIdForm::ATTRIBUTES.each do |attr|
          expect(flow.flow_session[:pii_from_user]).to_not have_key attr
        end

        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
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
          expect(flow.flow_session[:pii_from_user]).to_not have_key :dob

          step.call

          expect(flow.flow_session[:pii_from_user][:dob]).to eq '1988-09-03'
        end
      end
    end

    context 'when same_address_as_id is...' do
      let(:pii_from_user) { flow.flow_session[:pii_from_user] }
      let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
      let(:dob) { InPersonHelper::GOOD_DOB }
      # residential
      let(:address1) { InPersonHelper::GOOD_ADDRESS1 }
      let(:address2) { InPersonHelper::GOOD_ADDRESS2 }
      let(:city) { InPersonHelper::GOOD_CITY }
      let(:state) { InPersonHelper::GOOD_STATE }
      let(:zipcode) { InPersonHelper::GOOD_ZIPCODE }
      # identity_doc_
      let(:identity_doc_address1) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1 }
      let(:identity_doc_address2) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2 }
      let(:identity_doc_city) { InPersonHelper::GOOD_IDENTITY_DOC_CITY }
      let(:identity_doc_address_state) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS_STATE }
      let(:identity_doc_zipcode) { InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE }

      before(:each) do
        allow(user).to receive(:establishing_in_person_enrollment).
          and_return(enrollment)
      end

      context 'changed from "true" to "false"' do
        let(:submitted_values) do
          {
            dob:,
            same_address_as_id: 'false', # value on submission
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
          }
        end

        it 'marks address step as incomplete, retains identity_doc_ attrs/value
        but removes addr attr in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(flow.flow_session[:pii_from_user]).to_not have_key attr
          end

          make_pii

          # On Verify, user changes response from "Yes,..." to
          # "No, I live at a different address", see submitted_values above
          step.call

          # marks address step as incomplete
          address_step = flow.flow_session[Idv::Steps::InPerson::AddressStep.name]
          expect(address_step).to eq nil

          # retains identity_doc_ attributes and values in flow session
          expect(flow.flow_session[:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
          )

          # removes address attributes (non identity_doc_ attributes) in flow session
          expect(flow.flow_session[:pii_from_user]).not_to include(
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )
        end
      end

      context 'changed from "false" to "true"' do
        let(:submitted_values) do
          {
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
          }
        end

        it 'retains identity_doc_ attrs/value ands addr attr
        with same value as identity_doc in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(flow.flow_session[:pii_from_user]).to_not have_key attr
          end

          make_pii(same_address_as_id: 'false')

          # On Verify, user changes response from "No,..." to
          # "Yes, I live at the address on my state-issued ID
          step.call
          # expect addr attr values to the same as the identity_doc attr values
          expect(pii_from_user[:address1]).to eq identity_doc_address1
          expect(pii_from_user[:address2]).to eq identity_doc_address2
          expect(pii_from_user[:city]).to eq identity_doc_city
          expect(pii_from_user[:state]).to eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to eq identity_doc_zipcode
        end
      end

      context 'not changed from "false"' do
        let(:submitted_values) do
          {
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
          }
        end
        it 'retains identity_doc_ and addr attrs/value in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(flow.flow_session[:pii_from_user]).to_not have_key attr
          end

          # User picks "No, I live at a different address" on state ID
          make_pii(same_address_as_id: 'false')

          # On Verify, user does not changes response "No,..."
          step.call

          # retains identity_doc_ & addr attributes and values in flow session
          expect(flow.flow_session[:pii_from_user]).to include(
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
          pii_from_user = flow.flow_session[:pii_from_user]
          expect(pii_from_user[:address1]).to_not eq identity_doc_address1
          expect(pii_from_user[:address2]).to_not eq identity_doc_address2
          expect(pii_from_user[:city]).to_not eq identity_doc_city
          expect(pii_from_user[:state]).to_not eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to_not eq identity_doc_zipcode
        end
      end
    end
  end

  describe '#extra_view_variables' do
    let(:dob) { '1972-02-23' }
    let(:first_name) { 'First name' }
    let(:pii_from_user) { flow.flow_session[:pii_from_user] }
    let(:params) { ActionController::Parameters.new }
    let(:enrollment) { InPersonEnrollment.new }

    before(:each) do
      allow(step).to receive(:current_user).
        and_return(user)
      allow(user).to receive(:establishing_in_person_enrollment).
        and_return(enrollment)
    end

    context 'first name and dob are set' do
      it 'returns extra view variables' do
        pii_from_user[:dob] = dob
        pii_from_user[:first_name] = first_name

        expect(step.extra_view_variables).to include(
          pii: include(
            dob: dob,
            first_name: first_name,
          ),
          parsed_dob: Date.parse(dob),
          updating_state_id: true,
        )
      end
    end

    context 'first name is set' do
      it 'returns extra view variables' do
        pii_from_user[:first_name] = first_name

        expect(step.extra_view_variables).to include(
          pii: include(
            first_name: first_name,
          ),
          parsed_dob: nil,
          updating_state_id: true,
        )
      end
    end

    context 'dob is set' do
      it 'returns extra view variables' do
        pii_from_user[:dob] = dob

        expect(step.extra_view_variables).to include(
          pii: include(
            dob: dob,
          ),
          parsed_dob: Date.parse(dob),
          updating_state_id: false,
        )
      end
    end
  end

  describe 'skip address step?' do
    let(:pii_from_user) { flow.flow_session[:pii_from_user] }
    let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
    let(:enrollment) { InPersonEnrollment.new }
    let(:dob) { '1980-01-01' }
    let(:identity_doc_address_state) { 'Nevada' }
    let(:identity_doc_city) { 'Twin Peaks' }
    let(:identity_doc_address1) { '123 Sesame Street' }
    let(:identity_doc_address2) { 'Apt. #C' }
    let(:identity_doc_zipcode) { '90001' }
    let(:same_address_as_id) { 'true' }
    let(:submitted_values) do
      {
        dob: dob,
        identity_doc_address_state: identity_doc_address_state,
        identity_doc_city: identity_doc_city,
        identity_doc_address1: identity_doc_address1,
        identity_doc_address2: identity_doc_address2,
        identity_doc_zipcode: identity_doc_zipcode,
        same_address_as_id: same_address_as_id,
      }
    end

    before(:each) do
      allow(step).to receive(:current_user).
        and_return(user)
      allow(user).to receive(:establishing_in_person_enrollment).
        and_return(enrollment)
    end

    context 'same address as id' do
      it 'marks the address step as complete' do
        step.call

        address_step = flow.flow_session[Idv::Steps::InPerson::AddressStep.name]
        expect(address_step).to eq true
      end

      it 'adds state id values to address values in pii' do
        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:address1]).to eq identity_doc_address1
        expect(pii_from_user[:address2]).to eq identity_doc_address2
        expect(pii_from_user[:city]).to eq identity_doc_city
        expect(pii_from_user[:state]).to eq identity_doc_address_state
        expect(pii_from_user[:zipcode]).to eq identity_doc_zipcode
      end
    end

    context 'different address from id' do
      let(:same_address_as_id) { 'false' }
      it 'does not add state id values to address values in pii' do
        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:address1]).to_not eq identity_doc_address1
        expect(pii_from_user[:address2]).to_not eq identity_doc_address2
        expect(pii_from_user[:city]).to_not eq identity_doc_city
        expect(pii_from_user[:state]).to_not eq identity_doc_address_state
        expect(pii_from_user[:zipcode]).to_not eq identity_doc_zipcode
      end
    end
  end
end
