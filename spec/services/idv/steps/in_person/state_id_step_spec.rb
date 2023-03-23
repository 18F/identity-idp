require 'rails_helper'

describe Idv::Steps::InPerson::StateIdStep do
  let(:submitted_values) { {} }
  let(:params) { ActionController::Parameters.new({ state_id: submitted_values }) }
  let(:user) { build(:user) }
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
      let(:state_id_jurisdiction) { 'Nevada' }
      let(:state_id_number) { 'ABC123234' }
      let(:submitted_values) do
        {
          first_name: first_name,
          last_name: last_name,
          dob: dob,
          state_id_jurisdiction: state_id_jurisdiction,
          state_id_number: state_id_number,
        }
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
        expect(pii_from_user[:state_id_jurisdiction]).to eq state_id_jurisdiction
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
end
