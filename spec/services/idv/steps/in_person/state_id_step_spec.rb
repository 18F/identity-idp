require 'rails_helper'

describe Idv::Steps::InPerson::StateIdStep do
  let(:submitted_values) { {} }
  let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
  let(:user) { build(:user) }
  let(:capture_secondary_id_enabled) { false }
  let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      params: params,
      current_user: user,
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
      let(:state_id_state) { 'Nevada' }
      let(:state_id_number) { 'ABC123234' }
      let(:submitted_values) do
        {
          first_name: first_name,
          last_name: last_name,
          dob: dob,
          state_id_state: state_id_state,
          state_id_number: state_id_number,
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
          and_return(false)
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
        expect(pii_from_user[:state_id_state]).to eq state_id_state
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
  end

  describe '#extra_view_variables' do
    let(:dob) { '1972-02-23' }
    let(:first_name) { 'First name' }
    let(:pii_from_user) { flow.flow_session[:pii_from_user] }
    let(:params) { ActionController::Parameters.new }
    let(:capture_secondary_id_enabled) { true }
    let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }

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

    context 'with secondary capture enabled' do
      it 'returns capture enabled = true' do
        expect(step.extra_view_variables).to include(
          capture_secondary_id_enabled: true,
        )
      end
    end

    context 'with secondary capture disabled' do
      let(:capture_secondary_id_enabled) { false }
      it 'returns capture enabled = false' do
        expect(step.extra_view_variables).to include(
          capture_secondary_id_enabled: false,
        )
      end
    end
  end

  describe 'skip address step?' do
    let(:pii_from_user) { flow.flow_session[:pii_from_user] }
    let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
    let(:capture_secondary_id_enabled) { true }
    let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
    let(:dob) { '1980-01-01' }
    let(:state_id_state) { 'Nevada' }
    let(:state_id_city) { 'Twin Peaks' }
    let(:state_id_address1) { '123 Sesame Street' }
    let(:state_id_address2) { 'Apt. #C' }
    let(:state_id_zipcode) { '90001' }
    let(:same_address_as_id) { 'true' }
    let(:submitted_values) do
      {
        dob: dob,
        state_id_state: state_id_state,
        state_id_city: state_id_city,
        state_id_address1: state_id_address1,
        state_id_address2: state_id_address2,
        state_id_zipcode: state_id_zipcode,
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
        expect(pii_from_user[:address1]).to eq state_id_address1
        expect(pii_from_user[:address2]).to eq state_id_address2
        expect(pii_from_user[:city]).to eq state_id_city
        expect(pii_from_user[:state]).to eq state_id_state
        expect(pii_from_user[:zipcode]).to eq state_id_zipcode
      end
    end

    context 'different address from id' do
      let(:same_address_as_id) { 'false' }
      it 'does not add state id values to address values in pii' do
        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:address1]).to_not eq state_id_address1
        expect(pii_from_user[:address2]).to_not eq state_id_address2
        expect(pii_from_user[:city]).to_not eq state_id_city
        expect(pii_from_user[:state]).to_not eq state_id_state
        expect(pii_from_user[:zipcode]).to_not eq state_id_zipcode
      end
    end

    context 'capture secondary id is disabled' do
      let(:capture_secondary_id_enabled) { false }
      it 'does not add state id values to address values in pii' do
        step.call

        pii_from_user = flow.flow_session[:pii_from_user]
        expect(pii_from_user[:address1]).to_not eq state_id_address1
        expect(pii_from_user[:address2]).to_not eq state_id_address2
        expect(pii_from_user[:city]).to_not eq state_id_city
        expect(pii_from_user[:state]).to_not eq state_id_state
        expect(pii_from_user[:zipcode]).to_not eq state_id_zipcode
      end
    end
  end
end
